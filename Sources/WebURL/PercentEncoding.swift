// Copyright The swift-url Contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// A set of characters which should be transformed or substituted in order to percent-encode (or percent-escape) an ASCII string.
///
protocol PercentEncodeSet {

  /// Whether or not the given ASCII `character` should be percent-encoded.
  ///
  static func shouldEscape(character: ASCII) -> Bool

  /// An optional function which allows the encode-set to replace a non-percent-encoded character with another character.
  ///
  /// For example, the `application/x-www-form-urlencoded` encoding does not escape the space character, and instead replaces it with a "+".
  /// Conforming types must also implement the reverse substitution function, `unsubstitute(character:)`.
  ///
  /// - parameters:
  ///   - character: The source character.
  /// - returns:     The substitute character, or `nil` if the character should not be substituted.
  ///
  static func substitute(for character: ASCII) -> ASCII?

  /// An optional function which recovers a character from its substituted value.
  ///
  /// For example, the `application/x-www-form-urlencoded` encoding does not escape the space character, and instead replaces it with a "+".
  /// This function would thus return a space in place of a "+", so the original character can be recovered.
  /// Conforming types must also implement the substitution function, `substitute(for:)`.
  ///
  /// - parameters:
  ///   - character: The character from the encoded string.
  /// - returns:     The recovered original character, or `nil` if the character was not produced by this encode-set's substitution function.
  ///
  static func unsubstitute(character: ASCII) -> ASCII?
}

extension PercentEncodeSet {

  static func substitute(for character: ASCII) -> ASCII? {
    return nil
  }
  static func unsubstitute(character: ASCII) -> ASCII? {
    return nil
  }
}


// MARK: - Encoding.


extension LazyCollectionProtocol where Element == UInt8 {

  /// Returns a wrapper over this collection which lazily percent-encodes its contents according to the given `EncodeSet`.
  /// This collection is interpreted as UTF8-encoded text.
  ///
  /// Percent encoding transforms arbitrary strings to a limited set of ASCII characters which the `EncodeSet` permits.
  /// Non-ASCII characters and ASCII characters which are not allowed in the output, are encoded by replacing each byte with the sequence "%ZZ",
  /// where `ZZ` is the byte's value in hexadecimal.
  ///
  /// For example, the ASCII space character " " has a decimal value of 32 (0x20 hex). If the `EncodeSet` does not permit spaces in its output string,
  /// all spaces will be replaced by the sequence "%20". So the string "hello, world" becomes "hello,%20world" when percent-encoded.
  /// The character "✌️" is encoded in UTF8 as [0xE2, 0x9C, 0x8C, 0xEF, 0xB8, 0x8F] and since it is not ASCII, will be percent-encoded in every `EncodeSet`.
  /// This single-character string becomes "%E2%9C%8C%EF%B8%8F" when percent-encoded,
  ///
  /// `EncodeSet`s are also able to substitute characters. For example, the `application/x-www-form-urlencoded` encode-set percent-encodes
  /// the ASCII "+" character (0x2B), allowing that ASCII value to represent spaces. So the string "Swift is better than C++" becomes
  /// "Swift+is+better+than+C%2B%2B" in this encoding.
  ///
  /// The `LazilyPercentEncoded` wrapper is a collection-of-collections; each byte in the source collection is represented by a collection of either 1 or 3 bytes,
  /// depending on whether or not it was percent-encoded. The `.joined()` operator can be used if a one-dimensional collection is desired.
  ///
  /// -  important: Users should consider whether or not the "%" character itself should be part of their `EncodeSet`.
  /// If it is included, a string such as "%40 Polyester" would become "%2540%20Polyester", which can be decoded to exactly recover the original string.
  /// If it is _not_ included, strings such as the "%40" above would be copied to the output, where they would be indistinguishable from a percent-encoded byte
  /// and subsequently decoded as a byte value (in this case, the byte 0x40 is the ASCII commercial at, meaning the decoded string would be "@ Polyester").
  ///
  /// - parameters:
  ///     - encodeSet:    The set of ASCII characters which should be percent-encoded or substituted.
  ///
  func percentEncoded<EncodeSet>(using encodeSet: EncodeSet.Type) -> LazilyPercentEncoded<Self, EncodeSet> {
    return LazilyPercentEncoded(source: self, encodeSet: encodeSet)
  }
}

struct LazilyPercentEncoded<Source, EncodeSet>: Collection, LazyCollectionProtocol
where Source: Collection, Source.Element == UInt8, EncodeSet: PercentEncodeSet {
  let source: Source

  fileprivate init(source: Source, encodeSet: EncodeSet.Type) {
    self.source = source
  }

  typealias Index = Source.Index

  var startIndex: Index {
    return source.startIndex
  }

  var endIndex: Index {
    return source.endIndex
  }

  var isEmpty: Bool {
    return source.isEmpty
  }

  var underestimatedCount: Int {
    return source.underestimatedCount
  }

  var count: Int {
    return source.count
  }

  func index(after i: Index) -> Index {
    return source.index(after: i)
  }

  func formIndex(after i: inout Index) {
    return source.formIndex(after: &i)
  }

  func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
    return source.index(i, offsetBy: distance, limitedBy: limit)
  }

  func distance(from start: Index, to end: Index) -> Int {
    return source.distance(from: start, to: end)
  }

  subscript(position: Index) -> Element {
    let sourceByte = source[position]
    if let asciiChar = ASCII(sourceByte), EncodeSet.shouldEscape(character: asciiChar) == false {
      return EncodeSet.substitute(for: asciiChar).map { .substitutedByte($0.codePoint) } ?? .sourceByte(sourceByte)
    }
    return .percentEncodedByte(sourceByte)
  }

  enum Element: RandomAccessCollection {
    case sourceByte(UInt8)
    case substitutedByte(UInt8)
    case percentEncodedByte(UInt8)

    var startIndex: Int {
      return 0
    }

    var endIndex: Int {
      switch self {
      case .sourceByte, .substitutedByte:
        return 1
      case .percentEncodedByte:
        return 3
      }
    }

    var count: Int {
      return endIndex
    }

    subscript(position: Int) -> UInt8 {
      switch self {
      case .sourceByte(let byte):
        assert(position == 0, "Invalid index")
        return byte
      case .substitutedByte(let byte):
        assert(position == 0, "Invalid index")
        return byte
      case .percentEncodedByte(let byte):
        switch position {
        case 0: return ASCII.percentSign.codePoint
        case 1: return ASCII.getHexDigit_upper(byte &>> 4).codePoint
        case 2: return ASCII.getHexDigit_upper(byte).codePoint
        default: fatalError("Invalid index")
        }
      }
    }
  }
}

extension LazilyPercentEncoded: BidirectionalCollection where Source: BidirectionalCollection {

  func index(before i: Index) -> Index {
    return source.index(before: i)
  }

  func formIndex(before i: inout Index) {
    return source.formIndex(before: &i)
  }
}

extension LazilyPercentEncoded: RandomAccessCollection where Source: RandomAccessCollection {}

extension LazilyPercentEncoded {

  /// Calls the given closure with a temporary buffer containing part of the flattened percent-encoded string. The closure is called repeatedly until
  /// the entire string has been written.
  ///
  /// The string is written from start to end, so that appending the contents of each buffer to the contents of the previous buffers yields the final encoded string.
  /// The provided buffer must not escape the closure.
  ///
  /// - returns: A boolean indicating whether or not the final result differs from the source contents.
  ///            If this function returns `true`, some of the source collection's content was either percent-encoded or substituted.
  ///            If it returns `false`, the source collection is already percent-encoded.
  ///
  @discardableResult
  func writeBuffered(_ writer: (UnsafeBufferPointer<UInt8>) -> Void) -> Bool {

    return withSmallStringSizedStackBuffer { buffer -> Bool in
      let bufferSize = buffer.count
      // TODO: This is carefully written to appease the optimizer.
      // - precondition shouldn't be necessary.
      //   `withSmallStringSizedStackBuffer` gives a stack pointer which is never nil.
      // - bufferIdx is a UInt8 so the compiler knows it is never negative.
      //   `UnsafeBufferPointer.init(start:count:)` traps on negative count, even in release mode.
      //
      // Check if there is still a benefit if/when progress is made on https://github.com/apple/swift/pull/34747
      precondition(buffer.baseAddress != nil)
      var bufferIdx: UInt8 = 0
      var hasEncodedBytes = false

      for byteGroup in self {
        if bufferIdx &+ 3 > bufferSize {
          writer(UnsafeBufferPointer(start: buffer.baseAddress, count: Int(truncatingIfNeeded: bufferIdx)))
          bufferIdx = 0
        }
        // This appears to be the fastest way to fill the buffer. The non-loop alternative would be:
        // `UnsafeMutableBufferPointer(rebasing: buffer[bufferIdx...]).initialize(from: element)`,
        // which introduces all kinds of potential over/underflows and preconditions
        // that the compiler will not eliminate.
        for byte in byteGroup {
          buffer.baseAddress.unsafelyUnwrapped.advanced(by: Int(truncatingIfNeeded: bufferIdx)).initialize(to: byte)
          bufferIdx &+= 1
        }
        guard case .sourceByte = byteGroup else {
          hasEncodedBytes = true
          continue
        }
      }
      writer(UnsafeBufferPointer(start: buffer.baseAddress, count: Int(truncatingIfNeeded: bufferIdx)))
      return hasEncodedBytes
    }
  }

}

extension LazilyPercentEncoded where Source: BidirectionalCollection {

  /// Calls the given closure with a temporary buffer containing part of the flattened percent-encoded string. The closure is called repeatedly until
  /// the entire string has been written.
  ///
  /// - important: This function is similar to `writeBuffered`, except that the string is written in parts from the end to the start.
  ///              Each buffer's contents are in the correct order, but the buffers themselves represent a sliding window which begins at the
  ///              chunk containing the source collection's end and ends at the chunk containing the source collection's start.
  ///              The contents of each buffer may be _prepended_ to the contents of all previous buffers to yield the final encoded string.
  ///
  /// The provided buffer must not escape the closure.
  ///
  /// - returns: A boolean indicating whether or not the final result differs from the source contents.
  ///            If this function returns `true`, some of the source collection's content was either percent-encoded or substituted.
  ///            If it returns `false`, the source collection is already percent-encoded.
  ///
  @discardableResult
  func writeBufferedFromBack(_ writer: (UnsafeBufferPointer<UInt8>) -> Void) -> Bool {

    return withSmallStringSizedStackBuffer { buffer -> Bool in
      let bufferSize = buffer.count
      precondition(buffer.baseAddress != nil)
      var bufferIdx = buffer.endIndex
      var hasEncodedBytes = false

      for byteGroup in self.reversed() {
        if bufferIdx < 3 {
          writer(
            UnsafeBufferPointer(
              start: buffer.baseAddress.unsafelyUnwrapped + bufferIdx,
              count: bufferSize &- bufferIdx))
          bufferIdx = buffer.endIndex
        }
        for byte in byteGroup.reversed() {
          bufferIdx &-= 1
          buffer.baseAddress.unsafelyUnwrapped.advanced(by: bufferIdx).initialize(to: byte)
        }
        guard case .sourceByte = byteGroup else {
          hasEncodedBytes = true
          continue
        }
      }
      writer(
        UnsafeBufferPointer(
          start: buffer.baseAddress.unsafelyUnwrapped + bufferIdx,
          count: bufferSize &- bufferIdx))
      return hasEncodedBytes
    }
  }
}


// MARK: - Decoding.


extension LazyCollectionProtocol where Element == UInt8 {

  typealias LazilyPercentDecodedWithoutSubstitutions = LazilyPercentDecoded<Self, PassthroughEncodeSet>

  /// Returns a view of this collection with percent-encoded byte sequences ("%ZZ") replaced by the byte 0xZZ.
  ///
  /// This view does not account for substitutions in the source collection's encode-set.
  /// If it is necessary to decode such substitutions, use `percentDecoded(using:)` instead and provide the encode-set to reverse.
  ///
  /// - seealso: `LazilyPercentDecoded`
  ///
  var percentDecoded: LazilyPercentDecodedWithoutSubstitutions {
    return LazilyPercentDecoded(source: self)
  }

  /// Returns a view of this collection with percent-encoded byte sequences ("%ZZ") replaced by the byte 0xZZ.
  ///
  /// This view will reverse substitutions that were made by the given encode-set when encoding the source collection.
  ///
  /// - seealso: `LazilyPercentDecoded`
  ///
  func percentDecoded<EncodeSet>(using encodeSet: EncodeSet.Type) -> LazilyPercentDecoded<Self, EncodeSet> {
    return LazilyPercentDecoded(source: self)
  }
}

/// A collection which provides a view of its source collection with percent-encoded byte sequences ("%ZZ") replaced by the byte 0xZZ.
///
/// Some encode-sets perform substitutions as well as percent-encoding - e.g. URL form-encoding percent-encodes "+" characters but not " " (space) from the
/// source; spaces are then substituted with "+" characters so we know that every non-percent-encoded "+" represents a space. The `EncodeSet` generic
/// parameter is only used to reverse these substitutions; if such substitutions are not relevant to decoding,`PassthroughEncodeSet` may be given instead
/// of specifying a particular encode-set.
///
struct LazilyPercentDecoded<Source, EncodeSet>: Collection, LazyCollectionProtocol
where Source: Collection, Source.Element == UInt8, EncodeSet: PercentEncodeSet {
  typealias Element = UInt8

  let source: Source
  let startIndex: Index

  fileprivate init(source: Source) {
    self.source = source
    self.startIndex = Index(at: source.startIndex, in: source)
  }

  var endIndex: Index {
    return Index(endIndexOf: source)
  }

  func index(after i: Index) -> Index {
    assert(i != endIndex, "Attempt to advance endIndex")
    return Index(at: i.range.upperBound, in: source)
  }

  func formIndex(after i: inout Index) {
    assert(i != endIndex, "Attempt to advance endIndex")
    i = Index(at: i.range.upperBound, in: source)
  }

  subscript(position: Index) -> Element {
    assert(position != endIndex, "Attempt to read element at endIndex")
    return position.decodedValue
  }
}

extension LazilyPercentDecoded {

  /// A value which represents the location of a percent-encoded byte sequence in a source collection.
  ///
  /// The start index is given by `.init(at: source.startIndex, in: source)`.
  /// Each successive index is calculated by creating a new index at the previous index's `range.upperBound`, until an index is created whose
  /// `range.lowerBound` is the `endIndex` of the source collection.
  ///
  /// An index's `range` always starts at a byte which is not part of a percent-encode sequence, a percent sign, or `endIndex`, and each index
  /// represents a single decoded byte. This decoded value is stored in the index as `decodedValue`.
  ///
  struct Index: Comparable {
    let range: Range<Source.Index>
    let decodedValue: UInt8

    /// Creates an index referencing the given source collection's `endIndex`.
    /// This index's `decodedValue` is meaningless.
    ///
    init(endIndexOf source: Source) {
      self.range = Range(uncheckedBounds: (source.endIndex, source.endIndex))
      self.decodedValue = 0
    }

    /// Creates an index referencing the decoded byte starting at the given source index.
    ///
    /// The newly-created index's successor may be obtained by creating another index starting at `range.upperBound`.
    /// The index which starts at `source.endIndex` is given by `.init(endIndexOf:)`.
    ///
    init(at i: Source.Index, in source: Source) {
      guard i != source.endIndex else {
        self = .init(endIndexOf: source)
        return
      }
      let byte0 = source[i]
      let byte1Index = source.index(after: i)
      guard _slowPath(byte0 == ASCII.percentSign.codePoint) else {
        self.decodedValue = ASCII(byte0).flatMap { EncodeSet.unsubstitute(character: $0)?.codePoint } ?? byte0
        self.range = Range(uncheckedBounds: (i, byte1Index))
        return
      }
      var tail = source.suffix(from: byte1Index)
      guard let byte1 = tail.popFirst(),
        let decodedByte1 = ASCII(byte1).map(ASCII.parseHexDigit(ascii:)), decodedByte1 != ASCII.parse_NotFound,
        let byte2 = tail.popFirst(),
        let decodedByte2 = ASCII(byte2).map(ASCII.parseHexDigit(ascii:)), decodedByte2 != ASCII.parse_NotFound
      else {
        self.decodedValue = EncodeSet.unsubstitute(character: .percentSign)?.codePoint ?? ASCII.percentSign.codePoint
        self.range = Range(uncheckedBounds: (i, byte1Index))
        return
      }
      // decodedByte{1/2} are parsed from hex digits (i.e. in the range 0...15), so this will never overflow.
      self.decodedValue = (decodedByte1 &* 16) &+ (decodedByte2)
      self.range = Range(uncheckedBounds: (i, tail.startIndex))
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      return lhs.range.lowerBound == rhs.range.lowerBound
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
      return lhs.range.lowerBound < rhs.range.lowerBound
    }
  }
}


// MARK: - URL encode sets.


/// Percent-encodes the given UTF8 bytes with the appropriate `PercentEncodeSet` for a URL query string in a special/not-special scheme.
///
/// Equivalent to:
/// `source.lazy.percentEncoded(using: T.self).writeBuffered(writer)`,
/// where `T` is either `URLEncodeSet.Query_Special` or `.Query_NotSpecial`.
///
/// - seealso: `LazilyPercentEncoded.writeBuffered`
///
@discardableResult
func writeBufferedPercentEncodedQuery<Source>(
  _ source: Source,
  isSpecial: Bool,
  _ writer: (UnsafeBufferPointer<UInt8>) -> Void
) -> Bool where Source: Collection, Source.Element == UInt8 {

  if isSpecial {
    return source.lazy.percentEncoded(using: URLEncodeSet.Query_Special.self).writeBuffered(writer)
  } else {
    return source.lazy.percentEncoded(using: URLEncodeSet.Query_NotSpecial.self).writeBuffered(writer)
  }
}

/// An encode-set which does not escape or substitute any characters.
///
/// This is useful for decoding percent-encoded strings when we don't expect any characters to have been substituted, or when
/// the `PercentEncodeSet` used to encode the string is not known.
///
struct PassthroughEncodeSet: PercentEncodeSet {
  static func shouldEscape(character: ASCII) -> Bool {
    return false
  }
}

enum URLEncodeSet {

  struct C0: PercentEncodeSet {
    @inline(__always)
    static func shouldEscape(character: ASCII) -> Bool {
      //                 FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210
      let lo: UInt64 = 0b00000000_00000000_00000000_00000000_11111111_11111111_11111111_11111111
      let hi: UInt64 = 0b10000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000
      if character.codePoint < 64 {
        return lo & (1 &<< character.codePoint) != 0
      } else {
        return hi & (1 &<< (character.codePoint &- 64)) != 0
      }
    }
  }

  struct Fragment: PercentEncodeSet {
    @inline(__always)
    static func shouldEscape(character: ASCII) -> Bool {
      if C0.shouldEscape(character: character) { return true }
      //                 FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210
      let lo: UInt64 = 0b01010000_00000000_00000000_00000101_00000000_00000000_00000000_00000000
      let hi: UInt64 = 0b00000000_00000000_00000000_00000001_00000000_00000000_00000000_00000000
      if character.codePoint < 64 {
        return lo & (1 &<< character.codePoint) != 0
      } else {
        return hi & (1 &<< (character.codePoint &- 64)) != 0
      }
    }
  }

  struct Query_NotSpecial: PercentEncodeSet {
    @inline(__always)
    static func shouldEscape(character: ASCII) -> Bool {
      //                 FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210
      let lo: UInt64 = 0b01010000_00000000_00000000_00001101_11111111_11111111_11111111_11111111
      let hi: UInt64 = 0b10000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000
      if character.codePoint < 64 {
        return lo & (1 &<< character.codePoint) != 0
      } else {
        return hi & (1 &<< (character.codePoint &- 64)) != 0
      }
    }
  }

  struct Query_Special: PercentEncodeSet {
    @inline(__always)
    static func shouldEscape(character: ASCII) -> Bool {
      if Query_NotSpecial.shouldEscape(character: character) { return true }
      return character == .apostrophe
    }
  }

  struct Path: PercentEncodeSet {
    @inline(__always)
    static func shouldEscape(character: ASCII) -> Bool {
      if Fragment.shouldEscape(character: character) { return true }
      //                 FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210
      let lo: UInt64 = 0b10000000_00000000_00000000_00001000_00000000_00000000_00000000_00000000
      let hi: UInt64 = 0b00101000_00000000_00000000_00000000_00000000_00000000_00000000_00000000
      if character.codePoint < 64 {
        return lo & (1 &<< character.codePoint) != 0
      } else {
        return hi & (1 &<< (character.codePoint &- 64)) != 0
      }
    }
  }

  struct UserInfo: PercentEncodeSet {
    @inline(__always)
    static func shouldEscape(character: ASCII) -> Bool {
      if Path.shouldEscape(character: character) { return true }
      //                 FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210
      let lo: UInt64 = 0b00101100_00000000_10000000_00000000_00000000_00000000_00000000_00000000
      let hi: UInt64 = 0b00010000_00000000_00000000_00000000_01111000_00000000_00000000_00000001
      if character.codePoint < 64 {
        return lo & (1 &<< character.codePoint) != 0
      } else {
        return hi & (1 &<< (character.codePoint &- 64)) != 0
      }
    }
  }

  /// This encode-set is not used for any particular component, but can be used to encode data which is compatible with the escaping for
  /// the path, query, and fragment. It should give the same results as Javascript's `.encodeURIComponent()` method.
  ///
  struct Component: PercentEncodeSet {
    @inline(__always)
    static func shouldEscape(character: ASCII) -> Bool {
      if UserInfo.shouldEscape(character: character) { return true }
      //                 FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210_FEDCBA98_76543210
      let lo: UInt64 = 0b00000000_00000000_00011000_01110000_00000000_00000000_00000000_00000000
      let hi: UInt64 = 0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000
      if character.codePoint < 64 {
        return lo & (1 &<< character.codePoint) != 0
      } else {
        return hi & (1 &<< (character.codePoint &- 64)) != 0
      }
    }
  }

  struct FormEncoded: PercentEncodeSet {
    static func shouldEscape(character: ASCII) -> Bool {
      // Do not percent-escape spaces because we 'plus-escape' them instead.
      if character == .space { return false }
      switch character {
      case _ where character.isAlphaNumeric: return false
      case .asterisk, .minus, .period, .underscore: return false
      default: return true
      }
    }
    static func substitute(for character: ASCII) -> ASCII? {
      return character == .space ? .plus : nil
    }
    static func unsubstitute(character: ASCII) -> ASCII? {
      return character == .plus ? .space : nil
    }
  }
}
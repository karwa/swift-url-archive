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

import Checkit
import XCTest

@testable import WebURL

final class OtherUtilitiesTests: XCTestCase {}

extension OtherUtilitiesTests {

  func testNonURLCodePoints() {
    //    The URL code points are ASCII alphanumeric, U+0021 (!), U+0024 ($), U+0026 (&), U+0027 ('),
    //    U+0028 LEFT PARENTHESIS, U+0029 RIGHT PARENTHESIS, U+002A (*), U+002B (+), U+002C (,), U+002D (-),
    //    U+002E (.), U+002F (/), U+003A (:), U+003B (;), U+003D (=), U+003F (?), U+0040 (@), U+005F (_),
    //    U+007E (~), and code points in the range U+00A0 to U+10FFFD, inclusive, excluding surrogates and noncharacters.

    XCTAssertFalse(hasNonURLCodePoints(utf8: "alpha123".utf8))

    // ASCII.
    for asciiCharacter in stringWithEveryASCIICharacter {
      let isDisallowed = hasNonURLCodePoints(utf8: "alpha\(asciiCharacter)123".utf8)
      switch ASCII(asciiCharacter.utf8.first!)! {
      case ASCII.ranges.uppercaseAlpha, ASCII.ranges.lowercaseAlpha,
        ASCII.ranges.digits, .exclamationMark, .dollarSign, .ampersand, .apostrophe,
        .leftParenthesis, .rightParenthesis, .asterisk, .plus, .comma, .minus,
        .period, .forwardSlash, .colon, .semicolon, .equalSign, .questionMark, .commercialAt, .underscore,
        .tilde:
        XCTAssertFalse(isDisallowed)
      default:
        XCTAssertTrue(isDisallowed, String(asciiCharacter) + "(\(asciiCharacter.utf8.first!)")
      }
    }
    // Disallowed range up to U+00A0.
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0080}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0097}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{009F}123".utf8))
    // A sample of allowed non-ASCII codepoints.
    XCTAssertFalse(hasNonURLCodePoints(utf8: "alpha\u{00A0}123".utf8))
    XCTAssertFalse(hasNonURLCodePoints(utf8: "alpha\u{00F0}123".utf8))
    XCTAssertFalse(hasNonURLCodePoints(utf8: "alpha\u{00B0D0}123".utf8))
    XCTAssertFalse(hasNonURLCodePoints(utf8: "alpha\u{01ABC0}123".utf8))
    XCTAssertFalse(hasNonURLCodePoints(utf8: "alpha\u{06DEF0}123".utf8))
    XCTAssertFalse(hasNonURLCodePoints(utf8: "alpha\u{10FFFD}123".utf8))

    // Disallowed non-characters.
    func codeUnitsWithScalar(_ scalar: Unicode.Scalar) -> [UInt8] {
      var codeUnits: [UInt8] = [0x21]  // "!"
      UTF8.encode(scalar) { codeunit in codeUnits.append(codeunit) }
      XCTAssertGreaterThan(codeUnits.count, 1)
      codeUnits.append(0x3F)  // "?"
      return codeUnits
    }
    // String doesn't like it when we write some of these.
    XCTAssertFalse(hasNonURLCodePoints(utf8: codeUnitsWithScalar(Unicode.Scalar(0xFDCF)!)))
    XCTAssertTrue(hasNonURLCodePoints(utf8: codeUnitsWithScalar(Unicode.Scalar(0xFDD0)!)))
    XCTAssertTrue(hasNonURLCodePoints(utf8: codeUnitsWithScalar(Unicode.Scalar(0xFDDF)!)))
    XCTAssertTrue(hasNonURLCodePoints(utf8: codeUnitsWithScalar(Unicode.Scalar(0xFDEF)!)))
    XCTAssertFalse(hasNonURLCodePoints(utf8: codeUnitsWithScalar(Unicode.Scalar(0xFDF0)!)))

    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{01FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{01FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{02FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{02FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{03FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{03FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{04FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{04FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{05FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{05FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{06FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{06FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{07FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{07FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{08FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{08FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{09FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{09FFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0AFFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0AFFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0BFFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0BFFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0CFFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0CFFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0DFFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0DFFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0EFFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0EFFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0FFFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{0FFFFF}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{10FFFE}123".utf8))
    XCTAssertTrue(hasNonURLCodePoints(utf8: "alpha\u{10FFFF}123".utf8))

    // Surrogates.
    XCTAssertTrue(hasNonURLCodePoints(utf8: [0xED, 0xA0, 0x80]))  // D800
    XCTAssertTrue(hasNonURLCodePoints(utf8: [0xED, 0xAA, 0xBC]))  // DABC
    XCTAssertTrue(hasNonURLCodePoints(utf8: [0xED, 0xBF, 0xBF]))  // DFFF
  }

  func testForbiddenHostCodePoint() {
    /// A forbidden host code point is U+0000 NULL, U+0009 TAB, U+000A LF, U+000D CR,
    /// U+0020 SPACE, U+0023 (#), U+0025 (%), U+002F (/), U+003A (:), U+003C (<), U+003E (>),
    /// U+003F (?), U+0040 (@), U+005B ([), U+005C (\), U+005D (]), U+005E (^), or U+007C (|).
    for char in ASCII.allCharacters {
      switch char {
      case .null, .horizontalTab, .lineFeed, .carriageReturn, .space, .numberSign, .percentSign, .forwardSlash,
        .colon, .lessThanSign, .greaterThanSign, .questionMark, .commercialAt, .leftSquareBracket, .backslash,
        .rightSquareBracket, .circumflexAccent, .verticalBar:
        XCTAssertTrue(char.isForbiddenHostCodePoint)
      default:
        XCTAssertFalse(char.isForbiddenHostCodePoint)
      }
    }
  }
}

extension OtherUtilitiesTests {

  func testTempStorageIsValidURL() {
    let url = WebURL(storage: _tempStorage)
    XCTAssertEqual(url.serialized, "a:")
    XCTAssertURLIsIdempotent(url)
  }
}

extension OtherUtilitiesTests {

  func testFastInitialize() {
    let buffer = UnsafeMutableBufferPointer<Int>.allocate(capacity: 256)
    XCTAssertEqual(buffer.endIndex, 256)

    // Initialize with empty contiguous source. Should return 0.
    XCTAssertEqual(buffer.fastInitialize(from: []), 0)

    // Partially initialize from contiguous source. Should return number of elements written.
    XCTAssertEqual(buffer.fastInitialize(from: Array(0..<100)), 100)
    XCTAssertEqualElements(buffer[0..<100], 0..<100)

    // Fully initialize from contiguous source. Should return number of elements written.
    XCTAssertEqual(buffer.fastInitialize(from: Array(256..<512)), 256)
    XCTAssertEqualElements(buffer, 256..<512)

    // Initialize with a too-large contiguous source. Should return the buffer's endIndex.
    XCTAssertEqual(buffer.fastInitialize(from: Array(512..<4096)), buffer.endIndex)
    XCTAssertEqualElements(buffer, 512..<768)
  }
}

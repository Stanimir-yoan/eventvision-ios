import XCTest
@testable import EventVision

final class ScanGeometryTests: XCTestCase {
    private func p(_ x: Double,_ z: Double) -> RoomPoint { RoomPoint(x:x,y:-1.2,z:z) }
    func testRotatedRoomContract() throws {
        let points = [p(2,3),p(2,7),p(-1,7),p(-1,3)]
        let scan = try ScanGeometry.contract(points,id:"fixture")
        let room = try XCTUnwrap(scan["room"] as? [String:Any])
        XCTAssertEqual(try XCTUnwrap(room["area_m2"] as? Double),12,accuracy:0.00001)
        XCTAssertEqual(try XCTUnwrap(room["perimeter_m"] as? Double),14,accuracy:0.00001)
        let corners = try XCTUnwrap(room["corners"] as? [[String:Any]])
        let second = try XCTUnwrap(corners[1]["position_m"] as? [String:Double])
        XCTAssertEqual(try XCTUnwrap(second["x"]),4,accuracy:0.00001)
        XCTAssertEqual(try XCTUnwrap(second["z"]),0,accuracy:0.00001)
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject:scan))
    }
    func testRejectsCrossingsDuplicatesAndFlatRooms() {
        for points in [[p(0,0),p(4,3),p(0,3),p(4,0)],
                       [p(0,0),p(4,0),p(4,3),p(0,0)],
                       [p(0,0),p(1,0),p(2,0)]] {
            XCTAssertThrowsError(try ScanGeometry.validate(points))
        }
    }
    func testConcaveAndClockwiseRoomsAreValid() throws {
        let points = [p(0,0),p(4,0),p(4,4),p(2,2),p(0,4)]
        try ScanGeometry.validate(points)
        try ScanGeometry.validate(Array(points.reversed()))
    }
    func testRejectsNonFiniteAndDifferentFloors() {
        XCTAssertThrowsError(try ScanGeometry.validate([p(0,0),p(.infinity,0),p(1,2)]))
        XCTAssertThrowsError(try ScanGeometry.validate([p(0,0),p(4,0),RoomPoint(x:4,y:0,z:4)]))
    }
}

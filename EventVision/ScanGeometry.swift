import Foundation

struct RoomPoint: Codable, Equatable {
    var x: Double
    var y: Double
    var z: Double
}

enum ScanGeometry {
    enum Invalid: LocalizedError {
        case room(String)
        var errorDescription: String? {
            if case let .room(message) = self { return message }
            return nil
        }
    }
    static func distance(_ a: RoomPoint, _ b: RoomPoint) -> Double {
        hypot(a.x - b.x, a.z - b.z)
    }
    static func cross(_ a: RoomPoint, _ b: RoomPoint, _ c: RoomPoint) -> Double {
        (b.x-a.x)*(c.z-a.z) - (b.z-a.z)*(c.x-a.x)
    }
    static func intersects(_ a: RoomPoint, _ b: RoomPoint, _ c: RoomPoint, _ d: RoomPoint) -> Bool {
        let e = 0.000001
        func onSegment(_ p: RoomPoint, _ q: RoomPoint, _ r: RoomPoint) -> Bool {
            abs(cross(p,q,r)) < e && r.x >= min(p.x,q.x)-e && r.x <= max(p.x,q.x)+e &&
                r.z >= min(p.z,q.z)-e && r.z <= max(p.z,q.z)+e
        }
        let abC = cross(a,b,c), abD = cross(a,b,d), cdA = cross(c,d,a), cdB = cross(c,d,b)
        return (abC*abD < 0 && cdA*cdB < 0) || onSegment(a,b,c) || onSegment(a,b,d) ||
            onSegment(c,d,a) || onSegment(c,d,b)
    }
    static func validate(_ points: [RoomPoint]) throws {
        guard (3...256).contains(points.count) else { throw Invalid.room("Add at least three corners (maximum 256).") }
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
            throw Invalid.room("Tracking returned an invalid position. Scan again.")
        }
        for i in points.indices {
            guard abs(points[i].y-points[0].y) < 0.001 else { throw Invalid.room("Corners must share one floor.") }
            for j in points.indices where j > i {
                if distance(points[i],points[j]) < 0.05 { throw Invalid.room("Two corners are too close. Undo the last corner.") }
            }
            for j in points.indices where j > i {
                let nextI = (i+1)%points.count, nextJ = (j+1)%points.count
                if nextI == j || nextJ == i { continue }
                if intersects(points[i],points[nextI],points[j],points[nextJ]) {
                    throw Invalid.room("Walls cross. Add corners in order around the room.")
                }
            }
        }
        guard area(points) > 0.01 else { throw Invalid.room("The room has no usable area. Check the corners.") }
    }
    static func area(_ points: [RoomPoint]) -> Double {
        abs(points.indices.reduce(0) { value, i in
            let a = points[i], b = points[(i+1)%points.count]
            return value + a.x*b.z-b.x*a.z
        }) / 2
    }
    static func contract(_ points: [RoomPoint], id: String = UUID().uuidString) throws -> [String: Any] {
        try validate(points)
        let origin = points[0], length = distance(points[0],points[1])
        let ex = (points[1].x-origin.x)/length, ez = (points[1].z-origin.z)/length
        func vector(_ p: RoomPoint) -> [String: Double] { ["x":p.x,"y":p.y,"z":p.z] }
        func cornerID(_ i: Int) -> String { String(format:"corner_%02d",i+1) }
        let corners: [[String: Any]] = points.enumerated().map { i,p in
            let dx = p.x-origin.x, dz = p.z-origin.z
            return ["id":cornerID(i),"order":i+1,
                    "position_m":["x":dx*ex+dz*ez,"y":0,"z": -dx*ez+dz*ex],
                    "tracking_position_m":vector(p)]
        }
        let walls: [[String: Any]] = points.indices.map { i in
            ["id":String(format:"wall_%02d",i+1),"from_corner_id":cornerID(i),
             "to_corner_id":cornerID((i+1)%points.count),"length_m":distance(points[i],points[(i+1)%points.count])]
        }
        return ["schema":"eventvision_scan_result","version":1,"scan_id":id,
                "created_at":ISO8601DateFormatter().string(from:Date()),
                "app_protocol":"EventVision_v10_5_shared_scan_contract",
                "source":["provider":"arkit","platform":"ios","mode":"fresh_scan"],"units":"meters",
                "coordinate_system":["handedness":"right_handed","canonical_origin":"corner_01",
                    "canonical_x_axis":"corner_01_to_corner_02","vertical_axis":"Y","floor_plane":"XZ","canonical_floor_y_m":0],
                "tracking":["reference_space":"arkit_world","floor_y_m":origin.y,
                    "device_pose_at_finish":NSNull(),"projection_at_finish":NSNull()],
                "room":["closed":true,"area_m2":area(points),
                    "perimeter_m":points.indices.reduce(0) { $0 + distance(points[$1],points[($1+1)%points.count]) },
                    "corners":corners,"walls":walls],
                "quality":["corner_count":points.count,"floor_locked":true,"metric_scale":true]]
    }
}

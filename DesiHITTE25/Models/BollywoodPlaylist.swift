import Foundation

enum PlaylistCategory: String, Codable, CaseIterable {
    case highEnergy = "High Energy"
    case moderate = "Moderate"
    case coolDown = "Cool Down"
}

struct BollywoodPlaylist: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: PlaylistCategory
    let videoIDs: [String]

    init(name: String, category: PlaylistCategory, videoIDs: [String]) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.videoIDs = videoIDs
    }

    static let highEnergyPlaylist = BollywoodPlaylist(
        name: "Bollywood Fire 🔥",
        category: .highEnergy,
        videoIDs: [
            "l_MyUGq7pgs", // Malhari - Bajirao Mastani
            "YxWlaYCA6MU", // Khalibali - Padmaavat
            "Gc_jbBsSaa0", // Tattad Tattad - Goliyon Ki Raasleela Ram-Leela
            "JTcKB4OAXDE", // Naach Meri Rani
            "vTIIMJ9tUc8", // Garmi - Street Dancer 3D
            "BddP6PYo2gs", // Ghungroo - War
            "YoB8t0B4jx4", // Zingaat - Dhadak
            "Qlsfr66ONXM", // Nashe Si Chadh Gayi
            "yDr0fCRGxOA", // Kar Gayi Chull
            "r9_LnPOqOjY", // Badtameez Dil
            "AEIVhBS6baE", // Balam Pichkari
            "wTdRndh9EjM", // Senorita - Zindagi Na Milegi Dobara
        ]
    )

    static let moderatePlaylist = BollywoodPlaylist(
        name: "Bollywood Beats 🎵",
        category: .moderate,
        videoIDs: [
            "cYOB941gyXI", // Dil Diyan Gallan
            "gUjXjbbMFBg", // Tum Hi Ho
            "atGMFalVm1c", // Hawayein
            "pElk1ShPrcE", // Kal Ho Naa Ho
            "jHNNMj5bNQw", // Kabira
            "nIT3k1-tPWA", // Ilahi - Yeh Jawaani Hai Deewani
            "9sEI1AUFJKw", // Mast Magan
            "HVGJvJnOzh0", // Agar Tum Saath Ho
            "ik_BjYMhVbU", // Raabta Title Track
            "I0FP3bLbDnI", // Ae Dil Hai Mushkil Title Track
            "TH4V-yHbJXk", // Channa Mereya
        ]
    )

    static let coolDownPlaylist = BollywoodPlaylist(
        name: "Bollywood Chill 🌙",
        category: .coolDown,
        videoIDs: [
            "hoNb6HuNmU0", // Tujhe Dekha To
            "s3vhKGwSg_c", // Tera Ban Jaunga
            "fSS_R91Nimw", // Tum Se Hi - Jab We Met
            "cJ-RKCbzBnI", // Tujh Mein Rab Dikhta Hai
            "bx7l8e5M4-I", // Khairiyat - Chhichhore
            "Pa1otBbKb8g", // Mann Bharrya
        ]
    )

    static let allPlaylists: [BollywoodPlaylist] = [highEnergyPlaylist, moderatePlaylist, coolDownPlaylist]

    static func playlist(for category: PlaylistCategory) -> BollywoodPlaylist {
        switch category {
        case .highEnergy: return highEnergyPlaylist
        case .moderate: return moderatePlaylist
        case .coolDown: return coolDownPlaylist
        }
    }

    static func category(for zone: WorkoutZone) -> PlaylistCategory {
        switch zone {
        case .grey, .blue: return .coolDown
        case .green: return .moderate
        case .orange, .red: return .highEnergy
        }
    }
}

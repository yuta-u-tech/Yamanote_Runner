import Foundation

struct YamanoteStation: Identifiable, Hashable {
    let name: String
    let neighborhood: String

    var id: String { name }

    static let all: [YamanoteStation] = [
        .init(name: "東京", neighborhood: "丸の内"),
        .init(name: "神田", neighborhood: "神田"),
        .init(name: "秋葉原", neighborhood: "電気街"),
        .init(name: "御徒町", neighborhood: "上野広小路"),
        .init(name: "上野", neighborhood: "上野公園"),
        .init(name: "鶯谷", neighborhood: "根岸"),
        .init(name: "日暮里", neighborhood: "谷中"),
        .init(name: "西日暮里", neighborhood: "道灌山"),
        .init(name: "田端", neighborhood: "田端"),
        .init(name: "駒込", neighborhood: "六義園"),
        .init(name: "巣鴨", neighborhood: "地蔵通り"),
        .init(name: "大塚", neighborhood: "南大塚"),
        .init(name: "池袋", neighborhood: "東口"),
        .init(name: "目白", neighborhood: "目白"),
        .init(name: "高田馬場", neighborhood: "早稲田口"),
        .init(name: "新大久保", neighborhood: "大久保"),
        .init(name: "新宿", neighborhood: "南口"),
        .init(name: "代々木", neighborhood: "代々木"),
        .init(name: "原宿", neighborhood: "表参道口"),
        .init(name: "渋谷", neighborhood: "ハチ公口"),
        .init(name: "恵比寿", neighborhood: "恵比寿"),
        .init(name: "目黒", neighborhood: "権之助坂"),
        .init(name: "五反田", neighborhood: "西五反田"),
        .init(name: "大崎", neighborhood: "大崎"),
        .init(name: "品川", neighborhood: "港南口"),
        .init(name: "高輪ゲートウェイ", neighborhood: "高輪"),
        .init(name: "田町", neighborhood: "芝浦"),
        .init(name: "浜松町", neighborhood: "竹芝"),
        .init(name: "新橋", neighborhood: "汐留"),
        .init(name: "有楽町", neighborhood: "銀座口")
    ]

    static func named(_ name: String) -> YamanoteStation? {
        all.first { $0.name == name }
    }

    static func next(after station: YamanoteStation) -> YamanoteStation {
        guard let index = all.firstIndex(of: station) else { return all[0] }
        return all[(index + 1) % all.count]
    }
}

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DestruidorDeRed",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "DestruidorDeRed",
            path: "Sources/DestruidorDeRed",
            resources: [
                .copy("Resources/red.json"),
                .copy("Resources/red_colored.json"),
                .copy("Resources/veteran.json"),
                .copy("Resources/6pillars_basic.json"),
                .copy("Resources/veteran_cadozz.json"),
                .copy("Resources/lucky_girl.json"),
                .copy("Resources/cynthia_morimoto.json"),
                .copy("Resources/cynthia_morimoto_cadozz.json"),
                .copy("Resources/hooh.json"),
                .copy("Resources/hooh_trickroom.json"),
                .copy("Resources/cooldowns.json"),
                .copy("Resources/teams.json"),
                .copy("Resources/elite4-opponents.json"),
                .copy("Resources/en"),
                .copy("Resources/teams"),
                .copy("Resources/masterball.png"),
                .copy("Resources/sprites"),
                .copy("Resources/trainers"),
                .copy("Resources/regions"),
                .copy("Resources/items")
            ]
        )
    ]
)

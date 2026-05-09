import Cocoa
import CoreImage

// MARK: - Display mode

enum DisplayMode: Int {
    case desktop = 0
    case floating = 1

    /// Base level for the island widget.
    var islandLevel: NSWindow.Level {
        switch self {
        case .desktop:  return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        case .floating: return .floating
        }
    }
    /// Chicks always sit one level above the island, so they're never hidden by it.
    var chickLevel: NSWindow.Level {
        NSWindow.Level(rawValue: islandLevel.rawValue + 1)
    }
}

// MARK: - Chick visual styles

/// A renderable variant of the chick: how the spritesheet looks (pixel art vs
/// photo vs anime), how big its frames are, and whether hue tinting works on it.
struct ChickStyle {
    let id: String              // stable key for menu / cache
    let menuTitle: String
    let resourceName: String    // looked up first inside the .app bundle
    let fallbackPath: String    // dev-time absolute path used if resource missing
    let frameW: CGFloat
    let frameH: CGFloat
    let frameCount: Int
    let displaySize: CGFloat
    /// Photo-style sources look better with bicubic; pixel art needs nearest-neighbour.
    let useSmoothInterpolation: Bool
    /// Hue rotation looks great on flat-colour pixel art but ugly on a photo, so
    /// some styles disable colour variations entirely (every chick stays default).
    let supportsTints: Bool
}

/// All available chick styles. Order = order shown in the status-bar menu.
/// First entry is the default for new chicks until the user picks otherwise.
let chickStyles: [ChickStyle] = [
    ChickStyle(
        id: "anime", menuTitle: "Anime",
        resourceName: "chicken_anime",
        fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/chick_anime.png",
        frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
        useSmoothInterpolation: true, supportsTints: true
    ),
    ChickStyle(
        id: "realistic", menuTitle: "Realistic",
        resourceName: "chicken_realistic",
        fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/chick_realistic.png",
        frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
        useSmoothInterpolation: true, supportsTints: true
    ),
    ChickStyle(
        id: "memoji", menuTitle: "Memoji",
        resourceName: "chicken_memoji",
        fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/chick_memoji.png",
        frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
        useSmoothInterpolation: true, supportsTints: true
    ),
    ChickStyle(
        id: "lego", menuTitle: "Lego",
        resourceName: "chicken_lego",
        fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/chick_lego.png",
        frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
        useSmoothInterpolation: true, supportsTints: true
    ),
    ChickStyle(
        id: "embroidered", menuTitle: "Embroidered Felt",
        resourceName: "chicken_embroidered",
        fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/chick_embroidered.png",
        frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
        useSmoothInterpolation: true, supportsTints: true
    ),
    ChickStyle(
        id: "oil", menuTitle: "Oil Painting",
        resourceName: "chicken_oil",
        fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/chick_oil.png",
        frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
        useSmoothInterpolation: true, supportsTints: true
    ),
    ChickStyle(
        id: "psx", menuTitle: "PSX Low-Poly",
        resourceName: "chicken_psx",
        fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/chick_psx.png",
        frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
        useSmoothInterpolation: true, supportsTints: true
    ),
]

func chickStyle(forID id: String) -> ChickStyle {
    chickStyles.first(where: { $0.id == id }) ?? chickStyles[0]
}

// MARK: - Bunny visual styles
//
// Bunnies share the same id-space as chick styles so the "Chick Style" submenu
// flips both critters at once. Each bunny style points at a separate spritesheet
// (bunny_<id>.png), and is loaded lazily via Assets.bunnySheet(for:). If a
// bunny sheet for a particular id is missing, the bunny falls back to the
// `default` style at runtime — i.e. add bunny_anime.png first and you can
// already spawn bunnies; later styles plug in transparently.

struct BunnyStyle {
    let id: String              // shares ChickStyle ids — see chickStyles above
    let menuTitle: String
    let resourceName: String
    let fallbackPath: String
    let frameW: CGFloat
    let frameH: CGFloat
    let frameCount: Int
    let displaySize: CGFloat
    let useSmoothInterpolation: Bool
    let supportsTints: Bool
}

let bunnyStyles: [BunnyStyle] = [
    BunnyStyle(id: "anime", menuTitle: "Anime",
               resourceName: "bunny_anime",
               fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/bunny_anime.png",
               frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
               useSmoothInterpolation: true, supportsTints: true),
    BunnyStyle(id: "realistic", menuTitle: "Realistic",
               resourceName: "bunny_realistic",
               fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/bunny_realistic.png",
               frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
               useSmoothInterpolation: true, supportsTints: true),
    BunnyStyle(id: "memoji", menuTitle: "Memoji",
               resourceName: "bunny_memoji",
               fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/bunny_memoji.png",
               frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
               useSmoothInterpolation: true, supportsTints: true),
    BunnyStyle(id: "lego", menuTitle: "Lego",
               resourceName: "bunny_lego",
               fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/bunny_lego.png",
               frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
               useSmoothInterpolation: true, supportsTints: true),
    BunnyStyle(id: "embroidered", menuTitle: "Embroidered Felt",
               resourceName: "bunny_embroidered",
               fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/bunny_embroidered.png",
               frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
               useSmoothInterpolation: true, supportsTints: true),
    BunnyStyle(id: "oil", menuTitle: "Oil Painting",
               resourceName: "bunny_oil",
               fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/bunny_oil.png",
               frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
               useSmoothInterpolation: true, supportsTints: true),
    BunnyStyle(id: "psx", menuTitle: "PSX Low-Poly",
               resourceName: "bunny_psx",
               fallbackPath: "/Users/admin/Documents/vs projects 2026/chick/bunny_psx.png",
               frameW: 64, frameH: 64, frameCount: 4, displaySize: 64,
               useSmoothInterpolation: true, supportsTints: true),
]

func bunnyStyle(forID id: String) -> BunnyStyle {
    bunnyStyles.first(where: { $0.id == id }) ?? bunnyStyles[0]
}

// MARK: - Color tints (chick variations)

struct ChickTint {
    let name: String
    let hueShiftDegrees: CGFloat
    let saturationFactor: CGFloat
}

// Pre-defined palette. Hue shifted from yellow base; saturation tweaks for a few neutral tones.
let chickTints: [ChickTint] = [
    ChickTint(name: "yellow",   hueShiftDegrees:    0, saturationFactor: 1.0),
    ChickTint(name: "pink",     hueShiftDegrees:  300, saturationFactor: 0.9),
    ChickTint(name: "red",      hueShiftDegrees:  -60, saturationFactor: 1.1),
    ChickTint(name: "blue",     hueShiftDegrees:  180, saturationFactor: 1.0),
    ChickTint(name: "mint",     hueShiftDegrees:  120, saturationFactor: 0.85),
    ChickTint(name: "lavender", hueShiftDegrees:  240, saturationFactor: 0.8),
    ChickTint(name: "white",    hueShiftDegrees:    0, saturationFactor: 0.15),
    ChickTint(name: "brown",    hueShiftDegrees:  -20, saturationFactor: 0.55),
]

func tintedImage(_ source: NSImage, tint: ChickTint) -> NSImage {
    guard let tiff = source.tiffRepresentation,
          let ci = CIImage(data: tiff) else { return source }

    var image = ci
    if tint.hueShiftDegrees != 0 {
        let f = CIFilter(name: "CIHueAdjust")!
        f.setValue(image, forKey: kCIInputImageKey)
        f.setValue(NSNumber(value: Float(tint.hueShiftDegrees * .pi / 180)), forKey: kCIInputAngleKey)
        if let out = f.outputImage { image = out }
    }
    if abs(tint.saturationFactor - 1.0) > 0.001 {
        let f = CIFilter(name: "CIColorControls")!
        f.setValue(image, forKey: kCIInputImageKey)
        f.setValue(NSNumber(value: Float(tint.saturationFactor)), forKey: kCIInputSaturationKey)
        if let out = f.outputImage { image = out }
    }

    let rep = NSCIImageRep(ciImage: image)
    let result = NSImage(size: source.size)
    result.addRepresentation(rep)
    return result
}

/// Multiplies each RGB channel of `source` by the corresponding component of
/// `color`, leaving alpha untouched. Used for bunny tints because the bunny
/// art has near-white fur that has no hue for `CIHueAdjust` to rotate — a
/// multiply gives white × pink = pink, white × blue = blue, and so on, so
/// every tint actually changes the bunny's appearance.
func multiplyTinted(_ source: NSImage, by color: NSColor) -> NSImage {
    guard let tiff = source.tiffRepresentation,
          let ci = CIImage(data: tiff) else { return source }
    let rgb = color.usingColorSpace(.sRGB) ?? color
    let r = rgb.redComponent
    let g = rgb.greenComponent
    let b = rgb.blueComponent
    let f = CIFilter(name: "CIColorMatrix")!
    f.setValue(ci, forKey: kCIInputImageKey)
    f.setValue(CIVector(x: r, y: 0, z: 0, w: 0), forKey: "inputRVector")
    f.setValue(CIVector(x: 0, y: g, z: 0, w: 0), forKey: "inputGVector")
    f.setValue(CIVector(x: 0, y: 0, z: b, w: 0), forKey: "inputBVector")
    f.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
    guard let out = f.outputImage else { return source }
    let rep = NSCIImageRep(ciImage: out)
    let result = NSImage(size: source.size)
    result.addRepresentation(rep)
    return result
}

/// Multiplicative tint colours for bunnies — keyed by `ChickTint.name` so the
/// shared catalogue still drives the variety. Yellow is identity (no change)
/// so the seed bunny renders in its natural cream/white colour, matching the
/// chick's "yellow = default" convention.
let bunnyTintMultipliers: [String: NSColor] = [
    "yellow":   NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1),
    "pink":     NSColor(srgbRed: 1.00, green: 0.70, blue: 0.82, alpha: 1),
    "red":      NSColor(srgbRed: 1.00, green: 0.45, blue: 0.42, alpha: 1),
    "blue":     NSColor(srgbRed: 0.55, green: 0.72, blue: 1.00, alpha: 1),
    "mint":     NSColor(srgbRed: 0.62, green: 1.00, blue: 0.82, alpha: 1),
    "lavender": NSColor(srgbRed: 0.78, green: 0.68, blue: 1.00, alpha: 1),
    "white":    NSColor(srgbRed: 0.92, green: 0.93, blue: 0.96, alpha: 1),
    "brown":    NSColor(srgbRed: 0.72, green: 0.48, blue: 0.32, alpha: 1),
]

// MARK: - Asset registry

final class Assets {
    static let shared = Assets()

    /// Single-image anime island + coop (replaces the legacy pixel-art pair).
    let coopImage: NSImage

    /// Base spritesheet per style — loaded lazily on first request.
    private var chickSheetCache: [String: NSImage] = [:]
    /// Tinted spritesheet per (style, tint) — also lazy.
    private var tintedSheetCache: [String: NSImage] = [:]
    private var bunnySheetCache: [String: NSImage] = [:]
    private var tintedBunnySheetCache: [String: NSImage] = [:]

    private static func load(_ name: String, fallback: String) -> NSImage {
        if let img = loadOptional(name, fallback: fallback) { return img }
        NSLog("Missing asset: \(name)")
        exit(1)
    }

    private static func loadOptional(_ name: String, fallback: String) -> NSImage? {
        if let p = Bundle.main.path(forResource: name, ofType: "png"),
           let img = NSImage(contentsOfFile: p) { return img }
        if let img = NSImage(contentsOfFile: fallback) { return img }
        return nil
    }

    private init() {
        coopImage = Assets.load("coop",
            fallback: "/Users/admin/Documents/vs projects 2026/chick/new-chicks/coop.png")
    }

    /// Returns the (untinted) spritesheet for the given chick style, loading on demand.
    func chickSheet(for style: ChickStyle) -> NSImage {
        if let cached = chickSheetCache[style.id] { return cached }
        let img = Assets.load(style.resourceName, fallback: style.fallbackPath)
        chickSheetCache[style.id] = img
        return img
    }

    /// Returns the tinted spritesheet for (style, tint). Tint is ignored when
    /// the style doesn't support hue rotation (e.g. photo-realistic).
    func sheet(for tint: ChickTint, style: ChickStyle) -> NSImage {
        let key = "\(style.id)_\(tint.name)"
        if let cached = tintedSheetCache[key] { return cached }
        let base = chickSheet(for: style)
        let result = style.supportsTints ? tintedImage(base, tint: tint) : base
        tintedSheetCache[key] = result
        return result
    }

    /// Returns the (untinted) spritesheet for the given bunny style, or nil if
    /// the corresponding `bunny_<id>.png` asset has not been added yet. Caller
    /// is expected to fall back to a different style or skip rendering.
    func bunnySheet(for style: BunnyStyle) -> NSImage? {
        if let cached = bunnySheetCache[style.id] { return cached }
        guard let img = Assets.loadOptional(style.resourceName, fallback: style.fallbackPath)
        else { return nil }
        bunnySheetCache[style.id] = img
        return img
    }

    /// Returns the tinted spritesheet for (bunny style, tint), or nil when the
    /// underlying bunny sheet is missing. Uses *multiply* tinting (not the
    /// chick's hue-rotate) — the bunny art is dominated by near-white fur
    /// where `CIHueAdjust` has no hue to rotate, so multiply is the only
    /// path that actually colours every part of the bunny.
    func bunnySheetTinted(for tint: ChickTint, style: BunnyStyle) -> NSImage? {
        let key = "\(style.id)_\(tint.name)"
        if let cached = tintedBunnySheetCache[key] { return cached }
        guard let base = bunnySheet(for: style) else { return nil }
        let result: NSImage
        if style.supportsTints, let multiplier = bunnyTintMultipliers[tint.name] {
            result = multiplyTinted(base, by: multiplier)
        } else {
            result = base
        }
        tintedBunnySheetCache[key] = result
        return result
    }

    /// True when at least one bunny style has an asset on disk. Used to gate
    /// the "Spawn Bunny" menu item before any bunny art has been added.
    var anyBunnyArtAvailable: Bool {
        bunnyStyles.contains { bunnySheet(for: $0) != nil }
    }

    /// Returns the bunny style preferred for the current chick style. Falls
    /// back to the first bunny style whose asset is loadable, then to the
    /// raw default if every style is missing (the result is unrenderable but
    /// keeps the type non-optional for the call sites that need a style).
    func bunnyStyleAvailable(matching id: String) -> BunnyStyle {
        let exact = bunnyStyle(forID: id)
        if bunnySheet(for: exact) != nil { return exact }
        if let any = bunnyStyles.first(where: { bunnySheet(for: $0) != nil }) { return any }
        return exact
    }
}

// MARK: - Sounds

final class SoundManager {
    static let shared = SoundManager()
    private var chirpFiles: [URL] = []

    private init() {
        let exts = ["mp3", "wav", "aiff", "aif", "m4a", "caf"]
        var urls: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            let soundsDir = resourceURL.appendingPathComponent("sounds")
            if let contents = try? FileManager.default.contentsOfDirectory(at: soundsDir,
                                                                           includingPropertiesForKeys: nil) {
                for u in contents where exts.contains(u.pathExtension.lowercased()) {
                    urls.append(u)
                }
            }
            for ext in exts {
                if let found = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                    urls.append(contentsOf: found)
                }
            }
        }
        var seen = Set<String>()
        let unique = urls.filter { seen.insert($0.path).inserted }
        for u in unique where u.lastPathComponent.lowercased().hasPrefix("chirp") {
            chirpFiles.append(u)
        }
    }

    /// Plays a random chick chirp. Each call constructs a fresh NSSound so
    /// playbacks overlap cleanly.
    func playRandomChirp() { play(from: chirpFiles) }

    private func play(from files: [URL]) {
        guard let url = files.randomElement() else { return }
        if let s = NSSound(contentsOf: url, byReference: false) {
            s.play()
        }
    }
}

// MARK: - App state

final class AppState {
    static let shared = AppState()

    var displayMode: DisplayMode = .desktop {
        didSet { applyDisplayMode() }
    }
    var chicks: [ChickController] = []
    var bunnies: [BunnyController] = []
    var island: IslandController?

    private init() {}

    func applyDisplayMode() {
        for c in chicks { c.applyDisplayMode() }
        for b in bunnies { b.applyDisplayMode() }
        for s in snakes { s.applyDisplayMode() }
        island?.applyDisplayMode()
    }

    func toggleIsland() {
        if let isle = island {
            isle.close()
            island = nil
        } else {
            let isle = IslandController()
            isle.start()
            island = isle
        }
    }

    var currentChickStyle: ChickStyle = chickStyles[0] {
        didSet {
            if oldValue.id != currentChickStyle.id {
                recreateAllChicksWithCurrentStyle()
                recreateAllBunniesWithCurrentStyle()
            }
        }
    }

    /// Bunny style follows the chick style — bunnies use the bunnyStyle whose id
    /// matches `currentChickStyle.id`. If the corresponding bunny art isn't
    /// installed yet, falls back to whichever bunny art *is* available.
    var currentBunnyStyle: BunnyStyle {
        Assets.shared.bunnyStyleAvailable(matching: currentChickStyle.id)
    }

    func spawnChick(at point: NSPoint? = nil, tint: ChickTint? = nil,
                    isOriginal: Bool = false, style: ChickStyle? = nil) {
        let chosenTint = tint ?? chickTints.randomElement()!
        let chosenStyle = style ?? currentChickStyle
        let c = ChickController(tint: chosenTint, style: chosenStyle, isOriginal: isOriginal)
        c.start(at: point)
        chicks.append(c)
    }

    /// Snapshot every chick's position/tint/role, kill them, respawn with the
    /// current style. AI state is reset (chicks land back in idle wander).
    private func recreateAllChicksWithCurrentStyle() {
        struct Snap { let center: NSPoint; let tint: ChickTint; let isOriginal: Bool }
        let snaps: [Snap] = chicks.map {
            Snap(center: NSPoint(x: $0.window.frame.midX, y: $0.window.frame.midY),
                 tint: $0.tint, isOriginal: $0.isOriginal)
        }
        for c in chicks { c.close() }
        chicks.removeAll()
        for s in snaps {
            spawnChick(at: s.center, tint: s.tint, isOriginal: s.isOriginal,
                       style: currentChickStyle)
        }
    }

    func removeChick(_ c: ChickController) {
        chicks.removeAll { $0 === c }
    }

    /// True if at least one OTHER chick is currently outside the house. Enforces "always ≥1 visible".
    func anotherChickIsOutside(except: ChickController) -> Bool {
        return chicks.contains { $0 !== except && $0.aiState != .insideHouse }
    }

    /// Removes one chick on demand, most recent first. Originals are no longer
    /// protected — manual despawn can take the on-screen population to zero.
    /// The "last critter doesn't enter the coop" rule (`anotherChickIsOutside`)
    /// still keeps the lone chick visible against auto-despawn via coop visit.
    @discardableResult
    func despawnOneChick() -> Bool {
        guard let c = chicks.last else { return false }
        c.despawnNow()
        return true
    }

    // MARK: bunnies

    /// Spawns one bunny. Style follows the current chick style; if the matching
    /// bunny art is missing the call is a no-op so we don't render a blank box.
    func spawnBunny(at point: NSPoint? = nil, tint: ChickTint? = nil,
                    style: BunnyStyle? = nil) {
        let chosenTint = tint ?? chickTints.randomElement()!
        let chosenStyle = style ?? currentBunnyStyle
        guard Assets.shared.bunnySheet(for: chosenStyle) != nil else {
            NSLog("Spawn Bunny skipped: no asset for style \(chosenStyle.id)")
            return
        }
        let b = BunnyController(tint: chosenTint, style: chosenStyle)
        b.start(at: point)
        bunnies.append(b)
    }

    private func recreateAllBunniesWithCurrentStyle() {
        guard !bunnies.isEmpty else { return }
        struct Snap { let center: NSPoint; let tint: ChickTint }
        let snaps: [Snap] = bunnies.map {
            Snap(center: NSPoint(x: $0.window.frame.midX, y: $0.window.frame.midY),
                 tint: $0.tint)
        }
        for b in bunnies { b.close() }
        bunnies.removeAll()
        let style = currentBunnyStyle
        guard Assets.shared.bunnySheet(for: style) != nil else { return }
        for s in snaps {
            spawnBunny(at: s.center, tint: s.tint, style: style)
        }
    }

    func removeBunny(_ b: BunnyController) {
        bunnies.removeAll { $0 === b }
    }

    /// Mirrors `anotherChickIsOutside` — last bunny on screen doesn't enter the
    /// coop, so the user always sees at least one bunny if any are spawned.
    func anotherBunnyIsOutside(except: BunnyController) -> Bool {
        return bunnies.contains { $0 !== except && $0.aiState != .insideHouse }
    }

    /// Removes one bunny on demand, most recent first. No minimum — population
    /// can drop to zero via manual despawn.
    @discardableResult
    func despawnOneBunny() -> Bool {
        guard let b = bunnies.last else { return false }
        b.despawnNow()
        return true
    }

    // MARK: snakes

    var snakes: [SnakeController] = []

    /// Spawns one snake. Style cycles through the catalogue so multiple spawns
    /// surface different patterns before repeating.
    func spawnSnake(at point: NSPoint? = nil, style: SnakeStyle? = nil) {
        let chosenStyle = style ?? nextSnakeStyle()
        let s = SnakeController()
        s.start(at: point, style: chosenStyle)
        snakes.append(s)
    }

    private func nextSnakeStyle() -> SnakeStyle {
        // Prefer styles not currently present so spawns produce visual variety.
        let inUse = Set(snakes.map { $0.snake.style.id })
        let unused = snakeStyles.filter { !inUse.contains($0.id) }
        return (unused.randomElement() ?? snakeStyles.randomElement())!
    }

    func removeSnake(_ s: SnakeController) {
        snakes.removeAll { $0 === s }
    }

    /// Snake population can drop to zero (no minimum). Most recent first.
    @discardableResult
    func despawnOneSnake() -> Bool {
        for s in snakes.reversed() {
            s.despawnNow()
            return true
        }
        return false
    }

    /// Reassigns every spawned snake a fresh style from the catalogue. Picks
    /// each snake's new style from the pool of styles not already assigned this
    /// pass and not equal to the snake's current style, so a randomize on N
    /// snakes (N ≤ catalogue size) produces N distinct looks.
    @discardableResult
    func randomizeSnakes() -> Int {
        guard !snakes.isEmpty else { return 0 }
        var assigned: Set<String> = []
        for s in snakes.shuffled() {
            let currentId = s.snake.style.id
            let fresh = snakeStyles.filter { $0.id != currentId && !assigned.contains($0.id) }
            let pool = fresh.isEmpty
                ? snakeStyles.filter { $0.id != currentId }
                : fresh
            if let next = pool.randomElement() {
                s.applyStyle(next)
                assigned.insert(next.id)
            }
        }
        return snakes.count
    }
}

// MARK: - Chick view

final class ChickView: NSView {
    var spriteSheet: NSImage?
    var frameIndex: Int = 0 {
        didSet { if oldValue != frameIndex { needsDisplay = true } }
    }
    var facingLeft: Bool = false {
        didSet { if oldValue != facingLeft { needsDisplay = true } }
    }
    /// Frame layout is configured at construction time so the same view class
    /// works across every chick style.
    let frameCount: Int
    let frameW: CGFloat
    let frameH: CGFloat
    let useSmoothInterpolation: Bool

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
    }

    /// Set by the controller — invoked on mouseDown so chicks can chirp and
    /// bunnies can stay quiet (or call a different sound) without subclassing.
    var onMouseDown: (() -> Void)?

    /// Set by ChickController. Fires when the cursor crosses into the chick's
    /// hit-region — used to trigger the "startled, flee from mouse" behaviour.
    var onMouseEntered: (() -> Void)?

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        // Slight inset so the chick only flinches when the cursor is on/very-near its body,
        // not from the corners of the transparent 48×48 bounding box.
        let inset: CGFloat = 4
        let region = bounds.insetBy(dx: inset, dy: inset)
        let ta = NSTrackingArea(
            rect: region,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    /// Pixel-perfect-ish hit test: only count clicks where the current frame has visible alpha,
    /// so empty space around the round chick body falls through to whatever's underneath.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        guard let sheet = spriteSheet else { return self }

        // Map point in view-local space → frame-local pixel.
        let scaleX = bounds.width / frameW
        let scaleY = bounds.height / frameH
        var fx = point.x / scaleX
        let fy = point.y / scaleY
        if facingLeft { fx = frameW - fx }
        let srcX = CGFloat(frameIndex) * frameW + fx

        guard let rep = sheet.representations.first as? NSBitmapImageRep else { return self }
        let px = Int(srcX.rounded(.down))
        // Sheet stored top-down (PNG/CGImage origin); view y-up means PIL row = frameH - 1 - fy
        let py = Int((frameH - 1 - fy).rounded(.down))
        if px < 0 || py < 0 || px >= rep.pixelsWide || py >= rep.pixelsHigh { return self }
        if let color = rep.colorAt(x: px, y: py), color.alphaComponent > 0.05 { return self }
        return nil
    }

    init(frame frameRect: NSRect, frameW: CGFloat, frameH: CGFloat,
         frameCount: Int = 4, useSmoothInterpolation: Bool = false) {
        self.frameW = frameW
        self.frameH = frameH
        self.frameCount = frameCount
        self.useSmoothInterpolation = useSmoothInterpolation
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ss = spriteSheet else { return }
        let ctx = NSGraphicsContext.current
        if useSmoothInterpolation {
            ctx?.imageInterpolation = .high
            ctx?.shouldAntialias = true
        } else {
            ctx?.imageInterpolation = .none
            ctx?.shouldAntialias = false
        }

        let srcRect = NSRect(x: CGFloat(frameIndex) * frameW, y: 0, width: frameW, height: frameH)

        NSGraphicsContext.saveGraphicsState()
        if facingLeft {
            let t = NSAffineTransform()
            t.translateX(by: bounds.width, yBy: 0)
            t.scaleX(by: -1, yBy: 1)
            t.concat()
        }
        let interp: NSImageInterpolation = useSmoothInterpolation ? .high : .none
        ss.draw(in: NSRect(origin: .zero, size: bounds.size),
                from: srcRect, operation: .sourceOver, fraction: 1.0,
                respectFlipped: true,
                hints: [.interpolation: interp.rawValue])
        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - Chick controller

enum CritterAIState { case wandering, goingHome, insideHouse, talking, fleeing }

final class ChickController: NSObject {
    var window: NSWindow!
    var view: ChickView!
    var velocity: CGPoint = .zero
    /// Style determines sprite, frame size, display size, and tint behaviour.
    let style: ChickStyle
    var displaySize: CGFloat { style.displaySize }
    let tint: ChickTint
    var aiState: CritterAIState = .wandering
    let isOriginal: Bool
    /// House-spawned chicks have a finite lifetime, after which they walk home permanently.
    /// `nil` means immortal (the original chick).
    var despawnAt: Date?

    private let queue = DispatchQueue.main
    private var moveTimer: DispatchSourceTimer?
    private var animTimer: DispatchSourceTimer?
    private var stateTimer: DispatchSourceTimer?
    private var visitTimer: DispatchSourceTimer?
    private var talkChirpTimer: DispatchSourceTimer?

    /// Chicks that finished a chat get a cooldown so they don't immediately re-pair up.
    private var talkCooldownUntil: Date = Date(timeIntervalSinceNow: -1)
    private weak var talkPartner: ChickController?
    private var isOnTalkCooldown: Bool { Date() < talkCooldownUntil }

    /// Brief debounce so a fluttering cursor over the chick doesn't re-startle it every frame.
    private var fleeCooldownUntil: Date = Date(timeIntervalSinceNow: -1)

    init(tint: ChickTint, style: ChickStyle, isOriginal: Bool = false) {
        self.tint = tint
        self.style = style
        self.isOriginal = isOriginal
        if !isOriginal {
            self.despawnAt = Date().addingTimeInterval(Double.random(in: 60...180))
        }
    }

    func start(at point: NSPoint? = nil) {
        guard let screen = NSScreen.main else { exit(1) }
        let originX: CGFloat
        let originY: CGFloat
        if let p = point {
            originX = p.x - displaySize / 2
            originY = p.y - displaySize / 2
        } else {
            let vf = screen.visibleFrame
            originX = vf.midX - displaySize / 2
            originY = vf.midY - displaySize / 2
        }

        window = NSWindow(
            contentRect: NSRect(x: originX, y: originY, width: displaySize, height: displaySize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false // accept clicks (for chirp sounds)
        window.animationBehavior = .none
        window.level = AppState.shared.displayMode.chickLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        view = ChickView(
            frame: NSRect(x: 0, y: 0, width: displaySize, height: displaySize),
            frameW: style.frameW,
            frameH: style.frameH,
            frameCount: style.frameCount,
            useSmoothInterpolation: style.useSmoothInterpolation
        )
        view.spriteSheet = Assets.shared.sheet(for: tint, style: style)
        view.onMouseEntered = { [weak self] in self?.startled() }
        view.onMouseDown = { SoundManager.shared.playRandomChirp() }
        window.contentView = view
        window.orderFrontRegardless()

        beginIdle()
        scheduleNextHouseVisit()
    }

    func close() {
        cancelTimer(&moveTimer)
        cancelTimer(&animTimer)
        cancelTimer(&stateTimer)
        cancelTimer(&visitTimer)
        cancelTimer(&talkChirpTimer)
        window?.orderOut(nil)
    }

    func applyDisplayMode() {
        window?.level = AppState.shared.displayMode.chickLevel
    }

    // MARK: idle / wander

    private func cancelTimer(_ t: inout DispatchSourceTimer?) { t?.cancel(); t = nil }

    private func beginIdle() {
        aiState = .wandering
        velocity = .zero
        view.frameIndex = 0
        cancelTimer(&moveTimer)
        cancelTimer(&animTimer)
        scheduleStateChange(after: Double.random(in: 2.5...5.0)) { [weak self] in self?.beginMove() }
    }

    private func beginMove() {
        aiState = .wandering
        let speed: CGFloat = CGFloat.random(in: 1.4...2.4)
        let angle = CGFloat.random(in: 0..<(.pi * 2))
        velocity = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
        if abs(velocity.x) > 0.01 { view.facingLeft = velocity.x < 0 }
        startTimers(moveInterval: 1.0/30.0)
        scheduleStateChange(after: Double.random(in: 1.5...3.5)) { [weak self] in self?.beginIdle() }
    }

    // MARK: house visiting

    private func scheduleNextHouseVisit() {
        cancelTimer(&visitTimer)
        let delay = Double.random(in: 30...90)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + delay, leeway: .seconds(2))
        t.setEventHandler { [weak self] in self?.tryGoHome() }
        t.resume()
        visitTimer = t
    }

    private func tryGoHome() {
        guard aiState == .wandering, let isle = AppState.shared.island else {
            scheduleNextHouseVisit()
            return
        }
        let target = isle.houseDoorScreenPoint()
        beginGoingHome(to: target)
    }

    private func beginGoingHome(to target: NSPoint) {
        aiState = .goingHome
        let speed: CGFloat = 2.0
        startTimers(moveInterval: 1.0/30.0, target: target, speed: speed)
        cancelTimer(&stateTimer) // no random direction change — head straight there
    }

    private func enterHouse() {
        // Hard rule: never leave the desktop with zero visible chicks. The last one outside
        // turns around and resumes wandering.
        guard AppState.shared.anotherChickIsOutside(except: self) else {
            aiState = .wandering
            beginMove()
            scheduleNextHouseVisit()
            return
        }

        aiState = .insideHouse
        cancelTimer(&moveTimer); cancelTimer(&animTimer); cancelTimer(&stateTimer)
        window.orderOut(nil)

        let wantsToDespawn = !isOriginal && (despawnAt.map { Date() > $0 } ?? false)
        let stay = wantsToDespawn ? Double.random(in: 2...5) : Double.random(in: 6...18)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + stay, leeway: .seconds(1))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            if wantsToDespawn {
                self.despawnPermanently()
            } else {
                self.exitHouse()
            }
        }
        t.resume()
        visitTimer = t
    }

    private func despawnPermanently() {
        cancelTimer(&moveTimer); cancelTimer(&animTimer); cancelTimer(&stateTimer); cancelTimer(&visitTimer); cancelTimer(&talkChirpTimer)
        window?.orderOut(nil)
        AppState.shared.removeChick(self)
    }

    /// Public, immediate despawn (used by the menu's Despawn Chick action).
    func despawnNow() { despawnPermanently() }

    // MARK: chick-to-chick "talking"

    /// Looks for a nearby wandering chick to chat with. Both transition to .talking
    /// and exchange chirps before resuming their separate paths.
    private func checkTalkProximity() {
        guard aiState == .wandering, !isOnTalkCooldown else { return }
        guard AppState.shared.chicks.count >= 2 else { return } // need at least 2 chicks total
        let myCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let proximity: CGFloat = 60
        let p2 = proximity * proximity
        for other in AppState.shared.chicks where other !== self {
            guard other.aiState == .wandering, !other.isOnTalkCooldown else { continue }
            let oc = NSPoint(x: other.window.frame.midX, y: other.window.frame.midY)
            let dx = oc.x - myCenter.x
            let dy = oc.y - myCenter.y
            if dx * dx + dy * dy < p2 {
                beginTalking(with: other)
                other.beginTalking(with: self)
                return
            }
        }
    }

    func beginTalking(with partner: ChickController) {
        guard aiState != .talking else { return }
        aiState = .talking
        talkPartner = partner
        velocity = .zero
        cancelTimer(&moveTimer); cancelTimer(&animTimer); cancelTimer(&stateTimer)
        // Face the partner.
        let dxFace = partner.window.frame.midX - window.frame.midX
        if abs(dxFace) > 0.5 { view.facingLeft = dxFace < 0 }
        view.frameIndex = 0
        view.needsDisplay = true

        scheduleTalkChirp(initial: true)

        // End-of-conversation timer.
        let duration = Double.random(in: 4.0...6.5)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + duration, leeway: .milliseconds(300))
        t.setEventHandler { [weak self] in self?.endTalking() }
        t.resume()
        stateTimer = t
    }

    private func scheduleTalkChirp(initial: Bool) {
        cancelTimer(&talkChirpTimer)
        let delay = initial ? Double.random(in: 0.25...0.6) : Double.random(in: 1.1...2.4)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + delay, leeway: .milliseconds(150))
        t.setEventHandler { [weak self] in
            guard let self = self, self.aiState == .talking else { return }
            SoundManager.shared.playRandomChirp()
            // Tiny visual: blip to frame 1, then back to 0 — gives the impression of speaking.
            self.view.frameIndex = 1
            self.view.needsDisplay = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                guard let self = self, self.aiState == .talking else { return }
                self.view.frameIndex = 0
                self.view.needsDisplay = true
            }
            self.scheduleTalkChirp(initial: false)
        }
        t.resume()
        talkChirpTimer = t
    }

    private func endTalking() {
        cancelTimer(&talkChirpTimer)
        talkPartner = nil
        talkCooldownUntil = Date(timeIntervalSinceNow: Double.random(in: 25...50))
        beginIdle()
    }

    // MARK: startle / flee from cursor

    /// Called when the mouse cursor enters the chick's hit region. Picks a flee
    /// vector pointing away from the cursor (with a small lateral jitter so the
    /// movement looks like a real animal sidestepping a threat) and runs at ~3×
    /// normal speed for a brief burst before settling back into wandering.
    func startled() {
        guard aiState != .fleeing,
              aiState != .insideHouse,
              Date() > fleeCooldownUntil
        else { return }

        // Compute flee direction: vector from mouse to chick, normalised.
        let mouseScreen = NSEvent.mouseLocation
        let chickCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
        var dx = chickCenter.x - mouseScreen.x
        var dy = chickCenter.y - mouseScreen.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < 0.5 {
            // Cursor right on top — pick a random direction so we always move.
            let a = CGFloat.random(in: 0..<(.pi * 2))
            dx = cos(a); dy = sin(a)
        } else {
            dx /= dist; dy /= dist
        }

        // Add a small perpendicular component (sidestep) so the flee path looks natural.
        let perpScale = CGFloat.random(in: -0.45...0.45)
        let perpX = -dy
        let perpY = dx
        var nx = dx + perpX * perpScale
        var ny = dy + perpY * perpScale
        let nlen = max(sqrt(nx * nx + ny * ny), 0.001)
        nx /= nlen; ny /= nlen

        let fleeSpeed: CGFloat = 5.5 // ~2-3× normal walk speed
        velocity = CGPoint(x: nx * fleeSpeed, y: ny * fleeSpeed)
        if abs(velocity.x) > 0.01 { view.facingLeft = velocity.x < 0 }

        aiState = .fleeing
        fleeCooldownUntil = Date(timeIntervalSinceNow: 1.8)

        // Cancel any current activity so flee takes priority.
        cancelTimer(&moveTimer)
        cancelTimer(&animTimer)
        cancelTimer(&stateTimer)
        cancelTimer(&talkChirpTimer)
        talkPartner = nil

        SoundManager.shared.playRandomChirp() // startled peep

        // Rapid wing-flap animation while fleeing.
        let at = DispatchSource.makeTimerSource(queue: queue)
        at.schedule(deadline: .now() + 0.08, repeating: 0.08, leeway: .milliseconds(20))
        at.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.view.frameIndex = (self.view.frameIndex + 1) % self.view.frameCount
        }
        at.resume()
        animTimer = at

        // Position update at 30 fps (re-uses tickMove which decelerates while .fleeing).
        let mt = DispatchSource.makeTimerSource(queue: queue)
        let interval = 1.0 / 30.0
        mt.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(10))
        mt.setEventHandler { [weak self] in self?.tickMove() }
        mt.resume()
        moveTimer = mt

        // Recover after a short burst and resume normal wandering.
        let duration = Double.random(in: 0.8...1.4)
        let st = DispatchSource.makeTimerSource(queue: queue)
        st.schedule(deadline: .now() + duration, leeway: .milliseconds(100))
        st.setEventHandler { [weak self] in self?.endFlee() }
        st.resume()
        stateTimer = st
    }

    private func endFlee() {
        beginMove()
    }

    private func exitHouse() {
        guard let isle = AppState.shared.island else {
            window.orderFrontRegardless(); beginIdle(); scheduleNextHouseVisit(); return
        }
        let p = isle.houseDoorScreenPoint()
        var f = window.frame
        f.origin = NSPoint(x: p.x - displaySize / 2, y: p.y - displaySize / 2)
        window.setFrame(f, display: false)
        window.orderFrontRegardless()
        beginMove()
        scheduleNextHouseVisit()
    }

    // MARK: shared timer setup (with optional steering target)

    private func startTimers(moveInterval: Double, target: NSPoint? = nil, speed: CGFloat = 0) {
        cancelTimer(&animTimer)
        let at = DispatchSource.makeTimerSource(queue: queue)
        at.schedule(deadline: .now() + 0.18, repeating: 0.18, leeway: .milliseconds(60))
        at.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.view.frameIndex = (self.view.frameIndex + 1) % self.view.frameCount
        }
        at.resume()
        animTimer = at

        cancelTimer(&moveTimer)
        let mt = DispatchSource.makeTimerSource(queue: queue)
        mt.schedule(deadline: .now() + moveInterval, repeating: moveInterval, leeway: .milliseconds(10))
        mt.setEventHandler { [weak self] in
            guard let self = self else { return }
            if let target = target, self.aiState == .goingHome {
                self.steerToward(target: target, speed: speed)
            } else {
                self.tickMove()
            }
        }
        mt.resume()
        moveTimer = mt
    }

    private func steerToward(target: NSPoint, speed: CGFloat) {
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let dx = target.x - center.x
        let dy = target.y - center.y
        let dist = sqrt(dx*dx + dy*dy)
        if dist < 24 { enterHouse(); return }
        let nx = dx / dist; let ny = dy / dist
        velocity = CGPoint(x: nx * speed, y: ny * speed)
        if abs(velocity.x) > 0.01 { view.facingLeft = velocity.x < 0 }
        var f = window.frame
        f.origin.x += velocity.x * 2  // 30fps step = 2x velocity
        f.origin.y += velocity.y * 2
        window.setFrameOrigin(f.origin)
    }

    private func centerIsOnAnyScreen(_ rect: NSRect) -> Bool {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.contains { $0.visibleFrame.contains(center) }
    }

    private func tickMove() {
        // Soft deceleration during a flee: looks more natural than constant flight speed.
        if aiState == .fleeing {
            velocity.x *= 0.985
            velocity.y *= 0.985
        }

        let dx = velocity.x * 2
        let dy = velocity.y * 2
        let current = window.frame
        var attempted = current
        attempted.origin.x += dx
        attempted.origin.y += dy

        if centerIsOnAnyScreen(attempted) {
            window.setFrameOrigin(attempted.origin)
            checkTalkProximity()
            return
        }

        var xOnly = current; xOnly.origin.x += dx
        var yOnly = current; yOnly.origin.y += dy
        let xValid = centerIsOnAnyScreen(xOnly)
        let yValid = centerIsOnAnyScreen(yOnly)

        if xValid && !yValid {
            velocity.y = -velocity.y
            window.setFrameOrigin(xOnly.origin)
        } else if !xValid && yValid {
            velocity.x = -velocity.x
            if abs(velocity.x) > 0.01 { view.facingLeft = velocity.x < 0 }
            window.setFrameOrigin(yOnly.origin)
        } else {
            velocity.x = -velocity.x
            velocity.y = -velocity.y
            if abs(velocity.x) > 0.01 { view.facingLeft = velocity.x < 0 }
            if !centerIsOnAnyScreen(current), let main = NSScreen.main {
                let vf = main.visibleFrame
                let recovered = NSRect(x: vf.midX - displaySize / 2, y: vf.midY - displaySize / 2,
                                       width: displaySize, height: displaySize)
                window.setFrameOrigin(recovered.origin)
            }
        }
    }

    private func scheduleStateChange(after seconds: Double, handler: @escaping () -> Void) {
        cancelTimer(&stateTimer)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + seconds, leeway: .milliseconds(200))
        t.setEventHandler(handler: handler)
        t.resume()
        stateTimer = t
    }
}

// MARK: - Bunny controller
//
// Bunnies are ground-bound *hoppers* — they don't walk continuously like the
// chick. Each move is a discrete hop with a 4-frame animation:
//
//   F0 idle  →  F1 crouch  →  F2 airborne  →  F3 landing  →  F0 idle
//
// During a hop the window glides along a parabolic arc: horizontal lerp from
// start to target, plus `h · sin(π · t/d)` vertical lift. Between hops the
// window is stationary on F0 for a randomised pause.
//
// Behaviour mirrors the chick where it makes sense:
//   * Periodic coop visits — bunny hops to the coop door and "enters" (window
//     orderOut), idles inside for a few seconds, then re-emerges.
//   * Cursor flee — when the cursor enters the bunny's bounding box, hops are
//     re-armed in rapid-fire mode pointing away from the cursor.
//   * Last-of-species rule — the lone bunny refuses to enter the coop, so the
//     desktop never goes dark while bunnies exist.

final class BunnyController: NSObject {
    var window: NSWindow!
    var view: ChickView!   // same parametric sprite renderer as the chick
    let style: BunnyStyle
    let tint: ChickTint
    var displaySize: CGFloat { style.displaySize }
    var aiState: CritterAIState = .wandering

    private let queue = DispatchQueue.main
    /// Drives the per-frame hop arc & frame index update while in flight.
    private var hopTickTimer: DispatchSourceTimer?
    /// Schedules the next hop after the resting pause between hops.
    private var hopScheduleTimer: DispatchSourceTimer?
    /// Schedules the periodic coop-visit decision and the inside-coop dwell.
    private var visitTimer: DispatchSourceTimer?

    // MARK: hop kinematics
    /// True while a hop is in progress; false during the idle pause.
    private var inHop: Bool = false
    private var hopStartedAt: Date = .distantPast
    private var hopDuration: TimeInterval = 0.5
    private var hopFromOrigin: NSPoint = .zero
    private var hopTargetOrigin: NSPoint = .zero
    private var hopHeight: CGFloat = 14
    /// Last hop's heading angle — used to bias the next hop toward similar
    /// directions so wandering paths feel natural rather than zig-zaggy.
    private var lastHopAngle: CGFloat = 0

    // MARK: cursor flee
    private var fleeUntil: Date = .distantPast
    private var fleeCooldownUntil: Date = .distantPast
    private var isFleeing: Bool { Date() < fleeUntil }

    init(tint: ChickTint, style: BunnyStyle) {
        self.tint = tint
        self.style = style
    }

    func start(at point: NSPoint? = nil) {
        guard let screen = NSScreen.main else { exit(1) }
        let originX: CGFloat
        let originY: CGFloat
        if let p = point {
            originX = p.x - displaySize / 2
            originY = p.y - displaySize / 2
        } else {
            let vf = screen.visibleFrame
            originX = CGFloat.random(in: vf.minX + 80 ... vf.maxX - 80) - displaySize / 2
            originY = CGFloat.random(in: vf.minY + 80 ... vf.maxY - 80) - displaySize / 2
        }

        window = NSWindow(
            contentRect: NSRect(x: originX, y: originY, width: displaySize, height: displaySize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.animationBehavior = .none
        window.level = AppState.shared.displayMode.chickLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        view = ChickView(
            frame: NSRect(x: 0, y: 0, width: displaySize, height: displaySize),
            frameW: style.frameW,
            frameH: style.frameH,
            frameCount: style.frameCount,
            useSmoothInterpolation: style.useSmoothInterpolation
        )
        view.spriteSheet = Assets.shared.bunnySheetTinted(for: tint, style: style)
            ?? Assets.shared.bunnySheet(for: style)
        view.onMouseEntered = { [weak self] in self?.startled() }
        // Bunny click is silent for now — chick has chirps, bunny stays quiet.
        view.onMouseDown = nil
        window.contentView = view
        window.orderFrontRegardless()

        lastHopAngle = CGFloat.random(in: 0..<(.pi * 2))
        scheduleNextHop()
        scheduleNextHouseVisit()
    }

    func close() {
        cancelTimer(&hopTickTimer)
        cancelTimer(&hopScheduleTimer)
        cancelTimer(&visitTimer)
        window?.orderOut(nil)
    }

    func applyDisplayMode() {
        window?.level = AppState.shared.displayMode.chickLevel
    }

    /// Public, immediate despawn — used by the menu's Despawn Bunny action.
    func despawnNow() {
        cancelTimer(&hopTickTimer)
        cancelTimer(&hopScheduleTimer)
        cancelTimer(&visitTimer)
        window?.orderOut(nil)
        AppState.shared.removeBunny(self)
    }

    // MARK: timer helpers
    private func cancelTimer(_ t: inout DispatchSourceTimer?) { t?.cancel(); t = nil }

    // MARK: hop loop

    /// Schedules the next hop after a randomised pause. Flee-mode shortens the
    /// pause dramatically so bunnies fire hops rapid-fire while the cursor is
    /// near.
    private func scheduleNextHop() {
        cancelTimer(&hopScheduleTimer)
        let delay: TimeInterval
        if isFleeing {
            delay = Double.random(in: 0.05...0.15)
        } else if aiState == .goingHome {
            delay = Double.random(in: 0.10...0.25)
        } else {
            delay = Double.random(in: 0.30...1.20)
        }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + delay, leeway: .milliseconds(40))
        t.setEventHandler { [weak self] in self?.startHop() }
        t.resume()
        hopScheduleTimer = t
    }

    /// Begins one hop — picks angle/distance, snapshots the origin, switches
    /// the view to crouch (F1), and arms the per-frame tick.
    private func startHop() {
        guard window != nil else { return }
        guard aiState != .insideHouse else { return }

        // Pick angle.
        let angle: CGFloat
        let distance: CGFloat
        let duration: TimeInterval
        let height: CGFloat

        if isFleeing {
            // Direction = vector from cursor → bunny, with light jitter so flees
            // don't all run on the same axis.
            let mouseScreen = NSEvent.mouseLocation
            let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
            var dx = center.x - mouseScreen.x
            var dy = center.y - mouseScreen.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < 0.5 {
                let a = CGFloat.random(in: 0..<(.pi * 2))
                dx = cos(a); dy = sin(a)
            } else {
                dx /= dist; dy /= dist
            }
            angle = atan2(dy, dx) + CGFloat.random(in: -0.30...0.30)
            distance = CGFloat.random(in: 55...80)
            duration = 0.30
            height = 18
        } else if aiState == .goingHome,
                  let target = AppState.shared.island?.houseDoorScreenPoint() {
            let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
            let dx = target.x - center.x
            let dy = target.y - center.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < 28 {
                enterHouse()
                return
            }
            angle = atan2(dy, dx) + CGFloat.random(in: -0.10...0.10)
            distance = min(CGFloat.random(in: 40...58), dist)
            duration = 0.50
            height = 14
        } else {
            // Wander: 60% persist within a small cone of the previous heading,
            // 40% pick a fresh random direction. Keeps trajectories meandering
            // instead of teleporting to random new vectors each hop.
            if CGFloat.random(in: 0...1) < 0.6 {
                angle = lastHopAngle + CGFloat.random(in: -0.7...0.7)
            } else {
                angle = CGFloat.random(in: 0..<(.pi * 2))
            }
            distance = CGFloat.random(in: 36...58)
            duration = 0.50
            height = 14
        }
        lastHopAngle = angle

        let from = window.frame.origin
        var target = NSPoint(x: from.x + distance * cos(angle),
                             y: from.y + distance * sin(angle))

        // Reflect off-screen targets — pick the opposite direction so the bunny
        // bounces away from the edge instead of tunneling.
        let targetCenter = NSPoint(x: target.x + displaySize / 2,
                                   y: target.y + displaySize / 2)
        if !centerIsOnAnyScreen(targetCenter) {
            let reversed = angle + .pi
            target = NSPoint(x: from.x + distance * cos(reversed),
                             y: from.y + distance * sin(reversed))
            lastHopAngle = reversed
            view.facingLeft = cos(reversed) < 0
        } else {
            view.facingLeft = cos(angle) < 0
        }

        hopFromOrigin = from
        hopTargetOrigin = target
        hopDuration = duration
        hopHeight = height
        hopStartedAt = Date()
        inHop = true
        view.frameIndex = 1   // crouch
        startHopTickLoop()
    }

    private func startHopTickLoop() {
        cancelTimer(&hopTickTimer)
        let interval = 1.0 / 60.0
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(2))
        t.setEventHandler { [weak self] in self?.tickHop() }
        t.resume()
        hopTickTimer = t
    }

    /// Per-frame hop progression — moves the window along a parabolic arc and
    /// updates the sprite frame index according to the hop phase.
    private func tickHop() {
        guard inHop, window != nil else { return }
        let elapsed = Date().timeIntervalSince(hopStartedAt)
        if elapsed >= hopDuration {
            // Land cleanly on target.
            window.setFrameOrigin(hopTargetOrigin)
            view.frameIndex = 0
            inHop = false
            cancelTimer(&hopTickTimer)
            scheduleNextHop()
            return
        }
        let progress = CGFloat(elapsed / hopDuration)
        let xLerp = hopFromOrigin.x + (hopTargetOrigin.x - hopFromOrigin.x) * progress
        let yBaseline = hopFromOrigin.y + (hopTargetOrigin.y - hopFromOrigin.y) * progress
        let yArc = yBaseline + hopHeight * sin(.pi * progress)
        window.setFrameOrigin(NSPoint(x: xLerp, y: yArc))

        // Frame phase — crouch tail, airborne body, landing tail.
        if progress < 0.15 {
            view.frameIndex = 1
        } else if progress < 0.85 {
            view.frameIndex = 2
        } else {
            view.frameIndex = 3
        }
    }

    private func centerIsOnAnyScreen(_ point: NSPoint) -> Bool {
        return NSScreen.screens.contains { $0.visibleFrame.contains(point) }
    }

    // MARK: house visiting

    private func scheduleNextHouseVisit() {
        cancelTimer(&visitTimer)
        let delay = Double.random(in: 30...90)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + delay, leeway: .seconds(2))
        t.setEventHandler { [weak self] in self?.tryGoHome() }
        t.resume()
        visitTimer = t
    }

    private func tryGoHome() {
        guard aiState == .wandering, AppState.shared.island != nil else {
            scheduleNextHouseVisit()
            return
        }
        aiState = .goingHome
    }

    private func enterHouse() {
        // Last-bunny rule: refuse to enter if no other bunny is outside, so the
        // user always has at least one visible until they explicitly despawn.
        guard AppState.shared.anotherBunnyIsOutside(except: self) else {
            aiState = .wandering
            scheduleNextHouseVisit()
            return
        }

        aiState = .insideHouse
        cancelTimer(&hopTickTimer)
        cancelTimer(&hopScheduleTimer)
        inHop = false
        window.orderOut(nil)

        // Bunnies don't auto-despawn from the coop the way chicks do — they
        // just rest inside, then come back out.
        let stay = Double.random(in: 6...18)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + stay, leeway: .seconds(1))
        t.setEventHandler { [weak self] in self?.exitHouse() }
        t.resume()
        visitTimer = t
    }

    private func exitHouse() {
        guard let isle = AppState.shared.island else {
            window.orderFrontRegardless()
            aiState = .wandering
            scheduleNextHop()
            scheduleNextHouseVisit()
            return
        }
        let p = isle.houseDoorScreenPoint()
        var f = window.frame
        f.origin = NSPoint(x: p.x - displaySize / 2, y: p.y - displaySize / 2)
        window.setFrame(f, display: false)
        window.orderFrontRegardless()
        aiState = .wandering
        scheduleNextHop()
        scheduleNextHouseVisit()
    }

    // MARK: cursor flee

    /// Cursor entered the bunny's hit-region — switch to flee-mode so the next
    /// hop fires almost immediately and aims away from the cursor. Subsequent
    /// hops keep firing rapidly until `fleeUntil` expires.
    func startled() {
        guard aiState != .insideHouse,
              Date() > fleeCooldownUntil
        else { return }
        fleeUntil = Date(timeIntervalSinceNow: Double.random(in: 1.6...2.4))
        fleeCooldownUntil = fleeUntil.addingTimeInterval(0.5)

        // Cancel any in-flight pause so the next hop fires now in flee mode.
        cancelTimer(&hopScheduleTimer)
        if !inHop {
            scheduleNextHop()
        }
    }
}

// MARK: - Island view

final class IslandView: NSView {
    /// The single anime coop+island image (500×500 src). Filled to the view's
    /// bounds at draw time using high-quality interpolation.
    var coopImage: NSImage?

    /// Hand-measured doorway location and source dimensions, extracted from
    /// coop.png by finding the largest dark-opaque region in the front wall.
    /// Image origin is top-left (PNG convention); doorPointLocal flips y for the
    /// view's bottom-up coordinate system.
    private let coopSrcW: CGFloat = 500
    private let coopSrcH: CGFloat = 500
    /// Doorway threshold — where the chick stands when it disappears inside.
    private let coopDoorX: CGFloat = 277
    private let coopDoorY: CGFloat = 246
    /// Bounding box of the wooden coop building (roof + walls + door) in image
    /// space — used as the click-to-spawn hit region. Excludes the dirt body
    /// hanging beneath the grass so dragging from the underside still works.
    private let coopBuildingX: CGFloat = 90
    private let coopBuildingY: CGFloat = 15
    private let coopBuildingW: CGFloat = 220
    private let coopBuildingH: CGFloat = 235

    /// Notify on bona-fide click on the coop (no drag).
    var onHouseClick: (() -> Void)?

    private var dragInitialMouse: NSPoint?
    private var dragInitialOrigin: NSPoint?
    private var dragMoved: Bool = false
    private var bouncePhase: CGFloat = 0
    private var bounceTimer: Timer?

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Click target in view-local coords — the wooden coop building.
    var coopClickRect: NSRect {
        let sx = bounds.width / coopSrcW
        let sy = bounds.height / coopSrcH
        // Image y is top-down, view y is bottom-up — flip the rect's y.
        return NSRect(
            x: bounds.minX + coopBuildingX * sx,
            y: bounds.maxY - (coopBuildingY + coopBuildingH) * sy,
            width: coopBuildingW * sx,
            height: coopBuildingH * sy
        )
    }

    /// Doorway threshold in view-local coords — where chicks emerge from / vanish into.
    var doorPointLocal: NSPoint {
        let xNorm = coopDoorX / coopSrcW
        let yNorm = coopDoorY / coopSrcH
        return NSPoint(x: bounds.minX + xNorm * bounds.width,
                       y: bounds.maxY - yNorm * bounds.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let coop = coopImage else { return }
        let ctx = NSGraphicsContext.current
        ctx?.imageInterpolation = .high
        ctx?.shouldAntialias = true
        var dst = bounds
        dst.origin.y += sin(bouncePhase) * 4 * (bouncePhase > 0 ? 1 : 0)
        coop.draw(in: dst, from: NSRect(origin: .zero, size: coop.size),
                  operation: .sourceOver, fraction: 1.0,
                  respectFlipped: true,
                  hints: [.interpolation: NSImageInterpolation.high.rawValue])
    }

    // MARK: drag / click

    override func mouseDown(with event: NSEvent) {
        dragInitialMouse = NSEvent.mouseLocation
        dragInitialOrigin = window?.frame.origin
        dragMoved = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragInitialMouse,
              let origin = dragInitialOrigin,
              let win = window else { return }
        let cur = NSEvent.mouseLocation
        let dx = cur.x - start.x
        let dy = cur.y - start.y
        if abs(dx) + abs(dy) > 3 { dragMoved = true }
        win.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragInitialMouse = nil
            dragInitialOrigin = nil
        }
        if dragMoved { return }
        let local = convert(event.locationInWindow, from: nil)
        if coopClickRect.contains(local) {
            triggerBounce()
            onHouseClick?()
        }
    }

    private func triggerBounce() {
        bouncePhase = 0
        bounceTimer?.invalidate()
        let start = Date()
        bounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > 0.5 {
                self.bouncePhase = 0
                self.needsDisplay = true
                t.invalidate()
                self.bounceTimer = nil
                return
            }
            // 0..π over 0.5s → one upward bounce
            self.bouncePhase = CGFloat(elapsed / 0.5) * .pi
            self.needsDisplay = true
        }
    }
}

// MARK: - Island controller

final class IslandController: NSObject {
    var window: NSWindow!
    var view: IslandView!

    func start() {
        // Anime coop is 500×500 src; rendered at 320×320 on screen.
        let w: CGFloat = 320
        let h: CGFloat = 320

        guard let screen = NSScreen.main else { exit(1) }
        let vf = screen.visibleFrame
        let originX = vf.midX - w / 2
        let originY = vf.midY - h / 2

        window = NSWindow(
            contentRect: NSRect(x: originX, y: originY, width: w, height: h),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isMovable = true
        window.animationBehavior = .none
        window.level = AppState.shared.displayMode.islandLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        view = IslandView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        view.coopImage = Assets.shared.coopImage
        view.onHouseClick = { [weak self] in self?.handleHouseClick() }
        window.contentView = view
        window.orderFrontRegardless()
    }

    func close() { window?.orderOut(nil) }
    func applyDisplayMode() { window?.level = AppState.shared.displayMode.islandLevel }

    /// Door coordinates in screen space (chick navigation target).
    func houseDoorScreenPoint() -> NSPoint {
        let local = view.doorPointLocal
        return view.window!.convertPoint(toScreen: local)
    }

    private func handleHouseClick() {
        // Spawn 1-3 critters at the door, each independently a random species
        // (chick or bunny) and a random tint. Tints are drawn without
        // replacement from a shuffled pool so a single click produces visual
        // variety rather than three of the same colour.
        let count = Int.random(in: 1...3)
        var pool = chickTints.shuffled()
        let bunniesAvailable = Assets.shared.anyBunnyArtAvailable
        for _ in 0..<count {
            if pool.isEmpty { pool = chickTints.shuffled() }
            let tint = pool.removeFirst()
            let door = houseDoorScreenPoint()
            // small random offset so they don't stack on top of each other
            let dx = CGFloat.random(in: -10...10)
            let dy = CGFloat.random(in: -4...4)
            let spawnPoint = NSPoint(x: door.x + dx, y: door.y + dy)
            // 50/50 between species when bunny art is installed, else chick only.
            let spawnBunny = bunniesAvailable && Bool.random()
            if spawnBunny {
                AppState.shared.spawnBunny(at: spawnPoint, tint: tint)
            } else {
                AppState.shared.spawnChick(at: spawnPoint, tint: tint)
            }
        }
    }
}

// MARK: - Snake style

/// Visual pattern templates for snake bodies. Movement is identical across all
/// styles — only colour, shape, and per-segment overlays differ.
enum SnakePattern {
    case solid              // single base colour
    case dorsalStripe       // base + lighter stripe along the spine
    case bands              // alternating base / secondary rings every few segments
    case blotches           // base + irregular secondary blobs along the back
    case checker            // base + offset secondary diamonds along the back
}

struct SnakeStyle {
    let id: String
    let menuTitle: String
    let baseColor: NSColor
    let secondaryColor: NSColor
    let pattern: SnakePattern
    /// Approximate body length in pixels (head to tail along the centerline).
    let length: CGFloat
    /// Body width at the front of the head (largest) and at the tail tip (thinnest).
    let headRadius: CGFloat
    let tailRadius: CGFloat
}

let snakeStyles: [SnakeStyle] = [
    SnakeStyle(id: "emerald", menuTitle: "Emerald Tree Boa",
               baseColor: NSColor(srgbRed: 0.18, green: 0.55, blue: 0.30, alpha: 1),
               secondaryColor: NSColor(srgbRed: 0.93, green: 0.95, blue: 0.78, alpha: 1),
               pattern: .dorsalStripe, length: 240, headRadius: 9.0, tailRadius: 2.4),
    SnakeStyle(id: "coral", menuTitle: "Coral Snake",
               baseColor: NSColor(srgbRed: 0.86, green: 0.20, blue: 0.18, alpha: 1),
               secondaryColor: NSColor(srgbRed: 0.99, green: 0.85, blue: 0.30, alpha: 1),
               pattern: .bands, length: 220, headRadius: 8.0, tailRadius: 2.2),
    SnakeStyle(id: "diamondback", menuTitle: "Diamondback",
               baseColor: NSColor(srgbRed: 0.66, green: 0.55, blue: 0.40, alpha: 1),
               secondaryColor: NSColor(srgbRed: 0.30, green: 0.22, blue: 0.14, alpha: 1),
               pattern: .checker, length: 270, headRadius: 11.0, tailRadius: 3.0),
    SnakeStyle(id: "albino", menuTitle: "Albino Burmese",
               baseColor: NSColor(srgbRed: 0.97, green: 0.94, blue: 0.84, alpha: 1),
               secondaryColor: NSColor(srgbRed: 0.97, green: 0.65, blue: 0.45, alpha: 1),
               pattern: .blotches, length: 250, headRadius: 10.5, tailRadius: 2.8),
    SnakeStyle(id: "garter", menuTitle: "Garter Snake",
               baseColor: NSColor(srgbRed: 0.18, green: 0.30, blue: 0.20, alpha: 1),
               secondaryColor: NSColor(srgbRed: 0.94, green: 0.86, blue: 0.30, alpha: 1),
               pattern: .dorsalStripe, length: 200, headRadius: 7.0, tailRadius: 2.0),
    SnakeStyle(id: "milk", menuTitle: "Milk Snake",
               baseColor: NSColor(srgbRed: 0.86, green: 0.20, blue: 0.18, alpha: 1),
               secondaryColor: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1),
               pattern: .bands, length: 230, headRadius: 8.5, tailRadius: 2.4),
    SnakeStyle(id: "ball", menuTitle: "Ball Python",
               baseColor: NSColor(srgbRed: 0.78, green: 0.62, blue: 0.36, alpha: 1),
               secondaryColor: NSColor(srgbRed: 0.20, green: 0.14, blue: 0.10, alpha: 1),
               pattern: .blotches, length: 280, headRadius: 12.0, tailRadius: 3.4),
    SnakeStyle(id: "racer", menuTitle: "Black Racer",
               baseColor: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.12, alpha: 1),
               secondaryColor: NSColor(srgbRed: 0.55, green: 0.55, blue: 0.58, alpha: 1),
               pattern: .solid, length: 240, headRadius: 8.5, tailRadius: 2.0),
]

func snakeStyle(forID id: String) -> SnakeStyle {
    snakeStyles.first(where: { $0.id == id }) ?? snakeStyles[0]
}

// MARK: - Snake simulator
//
// Locomotion model: lateral undulation via head-only sinusoidal heading swing,
// with the body following the head's trail at fixed arc-length spacing
// ("follow-the-leader"). Wave-length along the path is held roughly constant
// regardless of speed by tying the swing frequency to forward velocity. When the
// snake stops moving, the head also stops oscillating — there is no in-place
// wobble, which matches how real snakes look at rest.

/// One drawable body element. The simulator re-builds the array each tick.
struct SnakeSegment {
    var position: CGPoint   // global screen-coords
    var radius: CGFloat
    var tangent: CGFloat    // local heading at this segment (radians)
    /// Distance from the head along the body, in pixels.
    var arcLength: CGFloat
}

final class Snake {
    /// Mutable so the "Randomize Snakes" action can swap looks at runtime
    /// without respawning. All movement maths read this, so radius / colour /
    /// length update on the next simulator tick.
    var style: SnakeStyle
    /// Dense segmentation — the body is rendered as a continuous ribbon, so
    /// closely-spaced segments are what make curvature smooth. 56 over a 240 px
    /// snake = ~4 px arc-length spacing.
    let segmentCount: Int = 56

    /// Global screen coords — head world position.
    var head: CGPoint
    /// Baseline heading the body is steering along (no swing applied). Radians.
    var headingBase: CGFloat
    /// Current swing offset applied to the actual heading. Radians.
    private var swingPhase: CGFloat = 0
    /// Slow breathing phase — produces ±3% speed oscillation for organic rhythm.
    private var breathPhase: CGFloat = 0
    /// Lateral swing amplitude (peak heading deviation in radians). Larger values
    /// produce more pronounced S-curves in the trail and therefore in the body.
    let swingAmplitude: CGFloat = 0.70
    /// Wavelength of the swing along the path, in pixels. Frequency derives from
    /// `speed / wavelength` so the wave-shape on the path stays constant when
    /// the snake speeds up or slows down.
    let swingWavelength: CGFloat = 130

    /// Forward speed in pixels/sec. AI nudges this toward `targetSpeed`.
    var speed: CGFloat
    var targetSpeed: CGFloat
    /// Max angular velocity of `headingBase` toward `goalHeading` (rad/sec).
    /// 1.0 ≈ 57°/sec — slow and deliberate, matching real-snake reorientations.
    let turnRate: CGFloat = 1.0

    /// AI: steady wandering target, picked within combined screen visible-frames.
    var goalPoint: CGPoint
    var goalHeading: CGFloat = 0
    var nextDecisionAt: Date = .distantPast
    /// While set, the snake is paused/coiling: `targetSpeed` is held near zero.
    var pauseUntil: Date = .distantPast

    /// Head's recent path. Stored newest-first (index 0 = most recent head pos).
    /// Length kept high enough to span the entire body plus slack.
    private var trail: [CGPoint]
    /// Approximate spacing between trail entries (in pixels). Used to size buffer.
    /// Smaller step = denser trail = smoother per-segment interpolation.
    private let trailEntryStep: CGFloat = 1.0
    private var trailCapacity: Int { max(160, Int((style.length * 1.8) / trailEntryStep)) }

    /// Built each tick by `rebuildSegments()`. Index 0 = head.
    private(set) var segments: [SnakeSegment] = []

    // MARK: drag state
    //
    // While the user is dragging the snake by one of its body joints, the AI is
    // paused entirely and the body is simulated as a Verlet rope: positions
    // integrate under gravity + damping, distance constraints between adjacent
    // segments preserve body length, and a soft bend stiffness gives the snake
    // a rope-like rigidity instead of a chain-of-beads feel. The dragged joint
    // itself is pinned to (cursor - grabOffset) so it tracks the mouse exactly.

    /// Set while the user is dragging the snake. nil = AI controls movement.
    private(set) var dragInfo: DragInfo?
    private var dragTargetScreen: CGPoint = .zero
    private var physics: PhysicsState?

    /// Recent (timestamp, cursor-position) samples taken during a drag. Used to
    /// estimate release velocity so the snake can glide on after the user
    /// lets go — faster motion at release = longer slide before the AI takes
    /// over. Trimmed to the last ~120 ms each tick.
    private var dragVelocitySamples: [(t: TimeInterval, p: CGPoint)] = []

    /// Set when the snake is in the post-release "glide" phase: physics keeps
    /// running (no pin) under damping until motion settles, then control
    /// returns to the AI. nil = not gliding.
    private(set) var slideEndsAt: Date?

    struct DragInfo {
        /// Index into `segments` of the joint the user grabbed.
        var segmentIndex: Int
        /// (mouseDownScreen − segment.position) at grab time, so the joint
        /// stays under the same grip-point on the body for the whole drag.
        var grabOffset: CGPoint
    }

    private struct PhysicsState {
        /// Current segment positions in screen coords.
        var positions: [CGPoint]
        /// Previous-frame positions for Verlet integration (velocity = pos − prev).
        var prevPositions: [CGPoint]
        /// Length to maintain between segments[i] and segments[i+1]. Captured at
        /// drag start from the live snake silhouette so the body never stretches
        /// or compresses overall while being dragged.
        var restLengths: [CGFloat]
    }

    init(style: SnakeStyle, head: CGPoint, heading: CGFloat) {
        self.style = style
        self.head = head
        self.headingBase = heading
        self.goalHeading = heading
        let baseSpeed = CGFloat.random(in: 70...95)
        self.speed = baseSpeed
        self.targetSpeed = baseSpeed
        // Seed the trail with a straight tail behind the head so segments are
        // populated on the very first tick (no first-frame "spawn from a point").
        let cap = max(160, Int((style.length * 1.8) / trailEntryStep))
        var initialTrail: [CGPoint] = []
        initialTrail.reserveCapacity(cap)
        var p = head
        let seedDir = CGPoint(x: -cos(heading), y: -sin(heading))
        for _ in 0..<cap {
            initialTrail.append(p)
            p.x += seedDir.x * trailEntryStep
            p.y += seedDir.y * trailEntryStep
        }
        self.trail = initialTrail
        self.goalPoint = head
        rebuildSegments()
    }

    /// Returns the union visibleFrame: a point is "on screen" if any screen
    /// contains it. Used to keep wandering goals reachable.
    private static func screenUnionContains(_ p: CGPoint) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.contains(p) }
    }

    /// Picks a wander goal somewhere on a randomly chosen screen.
    private func pickNewGoal() {
        let screens = NSScreen.screens
        let s = screens.randomElement() ?? NSScreen.main!
        let vf = s.visibleFrame.insetBy(dx: 60, dy: 60)
        goalPoint = NSPoint(x: CGFloat.random(in: vf.minX...vf.maxX),
                            y: CGFloat.random(in: vf.minY...vf.maxY))
    }

    /// Re-evaluates higher-level state (goal, pause, speed bursts).
    private func tickAI(now: Date) {
        if now >= nextDecisionAt {
            // 70% pick a new goal; 15% pause and look around; 15% short dart.
            let r = CGFloat.random(in: 0...1)
            if r < 0.70 {
                pickNewGoal()
                targetSpeed = CGFloat.random(in: 70...95)
                nextDecisionAt = now.addingTimeInterval(Double.random(in: 6...12))
            } else if r < 0.85 {
                pauseUntil = now.addingTimeInterval(Double.random(in: 1.2...2.6))
                nextDecisionAt = pauseUntil.addingTimeInterval(0.05)
            } else {
                targetSpeed = CGFloat.random(in: 130...170)
                nextDecisionAt = now.addingTimeInterval(Double.random(in: 0.6...1.2))
            }
        }

        // Reaching the goal: pick again next tick.
        let dx = goalPoint.x - head.x
        let dy = goalPoint.y - head.y
        if dx * dx + dy * dy < 30 * 30 {
            nextDecisionAt = now
        }

        // If head wandered off all screens (rare — e.g. monitor unplugged),
        // immediately re-target somewhere safe.
        if !Snake.screenUnionContains(head) {
            pickNewGoal()
        }

        // Pause window controls speed.
        if now < pauseUntil {
            targetSpeed = 0
        }
    }

    /// One simulation step. `dt` is real elapsed seconds since the previous tick.
    func tick(dt: TimeInterval) {
        if dragInfo != nil {
            tickDragging(dt: dt)
            return
        }
        if slideEndsAt != nil {
            tickSliding(dt: dt)
            return
        }
        let now = Date()
        tickAI(now: now)

        // 1. Goal heading toward goalPoint.
        let dx = goalPoint.x - head.x
        let dy = goalPoint.y - head.y
        goalHeading = atan2(dy, dx)

        // 2. Smoothly rotate baseline heading toward goalHeading.
        var diff = goalHeading - headingBase
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        let maxStep = turnRate * CGFloat(dt)
        let step = max(-maxStep, min(maxStep, diff))
        headingBase += step

        // 3. Approach targetSpeed (acceleration, deceleration on pauses).
        let accel: CGFloat = 220   // px/sec² — both speeding up and braking
        let dv = targetSpeed - speed
        let speedStep = max(-accel * CGFloat(dt), min(accel * CGFloat(dt), dv))
        speed += speedStep

        // 3b. Speed breathing — gentle ±3% oscillation at ~0.5 Hz adds organic
        //     rhythm so the snake never moves at exactly constant velocity.
        breathPhase += 2 * .pi * 0.5 * CGFloat(dt)
        let breathing = 1.0 + 0.03 * sin(breathPhase)
        let effectiveSpeed = speed * breathing

        // 4. Compute lateral swing. Frequency = speed / wavelength so wave-length
        //    along the path stays constant. Amplitude scales with how fast we're
        //    moving relative to nominal — so a stopping snake gradually stops
        //    wagging its head, instead of cutting it off abruptly.
        let nominalSpeed: CGFloat = 80
        let ampScale = min(1.0, max(0.0, speed / nominalSpeed))
        let freq = effectiveSpeed / max(40, swingWavelength)
        swingPhase += 2 * .pi * freq * CGFloat(dt)
        let swing = swingAmplitude * ampScale * sin(swingPhase)
        let heading = headingBase + swing

        // 5. Move head forward.
        head.x += cos(heading) * effectiveSpeed * CGFloat(dt)
        head.y += sin(heading) * effectiveSpeed * CGFloat(dt)

        // 6. Append head to trail — but only when we've moved enough to keep
        //    spacing roughly even. Otherwise pause-frames would flood the buffer
        //    with duplicates and waste capacity.
        if let last = trail.first {
            let ddx = head.x - last.x
            let ddy = head.y - last.y
            if ddx * ddx + ddy * ddy >= trailEntryStep * trailEntryStep {
                trail.insert(head, at: 0)
            } else {
                // Update the latest entry so the body's first segment tracks the
                // head precisely even at sub-step movement.
                trail[0] = head
            }
        } else {
            trail.insert(head, at: 0)
        }
        if trail.count > trailCapacity { trail.removeLast(trail.count - trailCapacity) }

        rebuildSegments()
    }

    /// Walks back along the trail laying down segments at fixed arc-length
    /// spacing. Body radius linearly interpolates from head → tail.
    private func rebuildSegments() {
        let n = segmentCount
        let total = style.length
        let spacing = total / CGFloat(n - 1)

        var built: [SnakeSegment] = []
        built.reserveCapacity(n)

        // Walk through the trail accumulating arc-length. For each desired
        // arc-length s_i = i * spacing, find the matching trail position.
        var trailIdx = 0
        var accumulated: CGFloat = 0
        var prev = trail.first ?? head
        for i in 0..<n {
            let target = CGFloat(i) * spacing
            // Advance through trail entries until we cross `target`.
            while trailIdx < trail.count - 1 {
                let a = trail[trailIdx]
                let b = trail[trailIdx + 1]
                let segLen = hypot(b.x - a.x, b.y - a.y)
                if accumulated + segLen >= target {
                    let t: CGFloat = segLen > 0.0001 ? (target - accumulated) / segLen : 0
                    prev = NSPoint(x: a.x + (b.x - a.x) * t,
                                   y: a.y + (b.y - a.y) * t)
                    break
                }
                accumulated += segLen
                trailIdx += 1
                prev = b
            }
            // If the trail ran out (snake just spawned, edge case), extrapolate
            // along baseline heading backwards.
            if trailIdx >= trail.count - 1 {
                let need = target - accumulated
                prev = NSPoint(x: trail.last!.x - cos(headingBase) * need,
                               y: trail.last!.y - sin(headingBase) * need)
            }

            // Per-segment radius: piecewise profile that matches real snakes —
            //   * 0..10% (head shoulder): rapid taper from headRadius to body
            //   * 10..78% (trunk):         constant body radius
            //   * 78..100% (tail):         smooth eased taper to tailRadius
            // Linear head→tail interpolation produces a "carrot" shape that
            // looks unnatural; this profile gives the typical snake silhouette
            // with a chunky body and only the last quarter visibly tapering.
            let frac = CGFloat(i) / CGFloat(n - 1)
            let bodyRadius = style.headRadius * 0.78
            let radius: CGFloat
            if frac < 0.10 {
                let t = frac / 0.10
                radius = style.headRadius - (style.headRadius - bodyRadius) * (t * t)
            } else if frac < 0.78 {
                radius = bodyRadius
            } else {
                let t = (frac - 0.78) / 0.22
                let easedT = t * t
                radius = bodyRadius + (style.tailRadius - bodyRadius) * easedT
            }

            built.append(SnakeSegment(position: prev, radius: radius,
                                      tangent: 0, arcLength: target))
        }

        // Second pass: compute smoothed tangents using a 7-segment baseline
        // (i-3 → i+3). Wider baseline damps direction noise from sub-pixel
        // trail jitter and gives the ribbon edges a continuous-looking curvature
        // even when the body is in tight S-curves.
        for i in 0..<built.count {
            let lo = max(0, i - 3)
            let hi = min(built.count - 1, i + 3)
            let a = built[lo].position
            let b = built[hi].position
            // a is closer to head, b is closer to tail → atan2(a - b) points
            // forward (toward the head).
            built[i].tangent = atan2(a.y - b.y, a.x - b.x)
        }

        segments = built
    }

    // MARK: drag + verlet physics

    /// Returns the index of the closest segment whose visible disc contains
    /// `screenPoint`, or nil if the point is outside the body silhouette. A
    /// small grab tolerance is added so users can hit narrow tail segments
    /// without pixel-perfect precision.
    func hitSegmentIndex(atScreen screenPoint: CGPoint) -> Int? {
        guard !segments.isEmpty else { return nil }
        var bestIdx: Int? = nil
        var bestDistSq: CGFloat = .greatestFiniteMagnitude
        for (i, s) in segments.enumerated() {
            let dx = s.position.x - screenPoint.x
            let dy = s.position.y - screenPoint.y
            let distSq = dx * dx + dy * dy
            // Slop grows for thinner tail segments so they're still grabbable.
            let grabRadius = s.radius + max(3.0, 6.0 - s.radius * 0.5)
            if distSq <= grabRadius * grabRadius && distSq < bestDistSq {
                bestIdx = i
                bestDistSq = distSq
            }
        }
        return bestIdx
    }

    /// Begin dragging from `segmentIndex`. Pauses AI (and any in-progress
    /// glide), snapshots the current segment positions and inter-segment
    /// distances, and remembers the (cursor − segment) offset so the grip
    /// stays under the same point on the body for the whole drag.
    func beginDrag(segmentIndex: Int, atScreenPoint p: CGPoint) {
        guard segments.indices.contains(segmentIndex) else { return }
        let segPos = segments[segmentIndex].position
        let offset = CGPoint(x: p.x - segPos.x, y: p.y - segPos.y)
        dragInfo = DragInfo(segmentIndex: segmentIndex, grabOffset: offset)
        dragTargetScreen = p
        // Cancel any post-release slide — the user grabbed the snake again.
        slideEndsAt = nil
        // Halt motion: target speed → 0 so velocity-based effects (swing
        // amplitude, etc.) reset cleanly when the drag ends.
        targetSpeed = 0
        speed = 0
        swingPhase = 0
        // Reset velocity samples — start fresh for this drag.
        dragVelocitySamples.removeAll(keepingCapacity: true)
        dragVelocitySamples.append((t: CACurrentMediaTime(), p: p))
        // Snapshot positions / rest lengths from the live silhouette.
        let positions = segments.map { $0.position }
        var lengths: [CGFloat] = []
        lengths.reserveCapacity(max(0, positions.count - 1))
        for i in 0..<(positions.count - 1) {
            let a = positions[i], b = positions[i + 1]
            lengths.append(hypot(b.x - a.x, b.y - a.y))
        }
        physics = PhysicsState(positions: positions,
                               prevPositions: positions,
                               restLengths: lengths)
    }

    /// Update the cursor target during a drag. Called from mouseDragged.
    /// Records a timestamped sample so we can estimate release velocity.
    func updateDrag(toScreenPoint p: CGPoint) {
        dragTargetScreen = p
        let now = CACurrentMediaTime()
        dragVelocitySamples.append((t: now, p: p))
        // Trim samples older than ~120 ms — recent motion is what matters
        // for release velocity, ancient history just adds lag.
        let cutoff = now - 0.12
        var firstKeep = 0
        while firstKeep < dragVelocitySamples.count - 1
            && dragVelocitySamples[firstKeep].t < cutoff {
            firstKeep += 1
        }
        if firstKeep > 0 {
            dragVelocitySamples.removeFirst(firstKeep)
        }
    }

    /// Release the snake. If the user was actively flicking, transitions
    /// into a momentum-based slide that decays under heavy friction before
    /// the AI resumes; otherwise hands control straight back to the AI.
    func endDrag() {
        guard let drag = dragInfo else { return }
        let dragIdx = drag.segmentIndex
        let releaseVel = computeReleaseVelocity()
        let velMag = hypot(releaseVel.x, releaseVel.y)
        dragInfo = nil
        dragVelocitySamples.removeAll(keepingCapacity: true)

        // Threshold: faster than ~150 px/s = "thrown" → slide.
        // Slower = "set down" → AI resumes immediately.
        if velMag > 150, var state = physics {
            // Mass scaling — heavy snake. The user's flick imparts momentum
            // proportional to (mass × Δv); for fixed input speed a heavier
            // body translates at a fraction of cursor speed. Velocity is
            // also capped so a wild whip doesn't fling it across the screen.
            let massScale: CGFloat = 0.45
            let velCap: CGFloat = 520    // px/sec — terminal thrown speed
            var sx = releaseVel.x * massScale
            var sy = releaseVel.y * massScale
            let smag = hypot(sx, sy)
            if smag > velCap {
                let k = velCap / smag
                sx *= k; sy *= k
            }

            // Ragdoll falloff: peak velocity at the grabbed joint, tapering
            // off along the body. Far segments keep their natural drag
            // physics velocities (sag / swing momentum from the hang), so
            // the body trails behind the throw and flops realistically
            // rather than translating as a rigid plank.
            //
            // Verlet: velocity = (pos − prev). To add `v_add` of velocity,
            // shift prev backward by `v_add * Δt` so next integration step
            // picks it up.
            let assumedDt: CGFloat = 1.0 / 60.0
            let n = state.positions.count
            for i in 0..<n {
                let dist = abs(i - dragIdx)
                // 1.0 at grip → ~0.45 far away. Linear falloff over ~14
                // segments (about a quarter of the body length).
                let falloff = max(CGFloat(0.45),
                                  1.0 - CGFloat(dist) * (0.55 / 14.0))
                state.prevPositions[i].x -= sx * assumedDt * falloff
                state.prevPositions[i].y -= sy * assumedDt * falloff
            }
            physics = state
            // Slide duration scales with the imparted speed — hard flick
            // ~0.7 s, gentle toss ~0.2 s. Heavy friction in tickSliding does
            // the actual deceleration; this just caps how long we hold off
            // the AI.
            let glideSeconds = min(0.7, max(0.20, Double(hypot(sx, sy) / 700)))
            slideEndsAt = Date().addingTimeInterval(glideSeconds)
            return
        }

        // No appreciable velocity → settle and resume AI immediately.
        finishGlide()
    }

    /// Average velocity over the trailing window of drag samples, in px/sec.
    /// Returns .zero if we don't have enough samples to estimate.
    private func computeReleaseVelocity() -> CGPoint {
        guard dragVelocitySamples.count >= 2 else { return .zero }
        let first = dragVelocitySamples.first!
        let last = dragVelocitySamples.last!
        let dt = last.t - first.t
        guard dt > 0.005 else { return .zero }
        return CGPoint(x: CGFloat((last.p.x - first.p.x) / CGFloat(dt)),
                       y: CGFloat((last.p.y - first.p.y) / CGFloat(dt)))
    }

    /// One physics step while the user is dragging. Verlet integration with
    /// gravity, distance constraints between adjacent segments, and a soft
    /// bend-stiffness pull for snake-like rigidity. The dragged segment is
    /// pinned to (cursor − grabOffset).
    private func tickDragging(dt: TimeInterval) {
        guard var state = physics, let drag = dragInfo else { return }
        let n = state.positions.count
        guard n >= 2 else { return }
        let dragIdx = max(0, min(n - 1, drag.segmentIndex))
        let target = CGPoint(x: dragTargetScreen.x - drag.grabOffset.x,
                             y: dragTargetScreen.y - drag.grabOffset.y)

        // 1. Verlet integration. Gravity is in macOS screen coords (y up), so
        //    falling = negative y. Damping caps oscillation when the user
        //    holds the snake still mid-air. Heavier damping on the inertia
        //    means muscle-like tone instead of a limp string oscillating.
        //    Gravity is intentionally light: a real snake's body has its own
        //    structural stiffness, so we want a soft drape — strong gravity
        //    overpowers per-joint bend stiffness and folds the body into a
        //    sharp V at the grip point.
        let gravityY: CGFloat = -380    // px/sec²
        let damping: CGFloat = 0.85     // velocity damping per frame
        let dt2 = CGFloat(dt * dt)
        let maxStep: CGFloat = 60       // hard cap per frame to avoid blowups
        for i in 0..<n {
            if i == dragIdx { continue }
            let pos = state.positions[i]
            let prev = state.prevPositions[i]
            var vx = (pos.x - prev.x) * damping
            var vy = (pos.y - prev.y) * damping
            vx = max(-maxStep, min(maxStep, vx))
            vy = max(-maxStep, min(maxStep, vy))
            let nx = pos.x + vx
            let ny = pos.y + vy + gravityY * dt2
            state.prevPositions[i] = pos
            state.positions[i] = CGPoint(x: nx, y: ny)
        }
        // Pin dragged segment with zero residual velocity.
        state.prevPositions[dragIdx] = target
        state.positions[dragIdx] = target

        // 2. Constraint solve. Multiple iterations propagate length / bend
        //    corrections all the way to the chain's far ends. The bend
        //    stiffness is what makes the body feel like a snake (muscle tone,
        //    resists sharp angles) instead of a chain of beads on a string.
        //    With 56 segments and per-segment bend pulls, the cumulative
        //    effect over many iterations builds a strong spine — iteration
        //    count and stiffness are paired knobs.
        let iterations = 24
        let bendStiffness: CGFloat = 0.30  // 0..1 — higher = stiffer "spine"
        for _ in 0..<iterations {
            // 2a. Distance constraints — keep adjacent segments at rest length.
            for i in 0..<(n - 1) {
                let pinA = (i == dragIdx)
                let pinB = ((i + 1) == dragIdx)
                if pinA && pinB { continue }
                let a = state.positions[i]
                let b = state.positions[i + 1]
                let dx = b.x - a.x
                let dy = b.y - a.y
                let dist = max(0.0001, sqrt(dx * dx + dy * dy))
                let rest = state.restLengths[i]
                let diff = (dist - rest) / dist
                let kA: CGFloat = pinA ? 0 : (pinB ? 1 : 0.5)
                let kB: CGFloat = pinB ? 0 : (pinA ? 1 : 0.5)
                state.positions[i].x += dx * diff * kA
                state.positions[i].y += dy * diff * kA
                state.positions[i + 1].x -= dx * diff * kB
                state.positions[i + 1].y -= dy * diff * kB
            }

            // 2b. Local bend stiffness — soft pull of every interior joint
            //     toward the midpoint of its immediate neighbours. Acts as an
            //     angular spring at the per-segment scale.
            for i in 1..<(n - 1) {
                if i == dragIdx { continue }
                let a = state.positions[i - 1]
                let b = state.positions[i + 1]
                let mid = CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
                let p = state.positions[i]
                state.positions[i].x = p.x + (mid.x - p.x) * bendStiffness
                state.positions[i].y = p.y + (mid.y - p.y) * bendStiffness
            }

            // 2c. Wide-stencil curvature smoothing — pull each joint toward
            //     the midpoint of segments 4 steps away on each side. This
            //     is what stops the body folding into a sharp V at the grip
            //     point: gravity's torque now distributes its bend across
            //     ~8 segments instead of concentrating at one hinge, which
            //     yields the smooth J-curve a real snake makes when held.
            let wideStiffness: CGFloat = 0.18
            let widePad = 4
            for i in widePad..<(n - widePad) {
                if i == dragIdx { continue }
                let a = state.positions[i - widePad]
                let b = state.positions[i + widePad]
                let mid = CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
                let p = state.positions[i]
                state.positions[i].x = p.x + (mid.x - p.x) * wideStiffness
                state.positions[i].y = p.y + (mid.y - p.y) * wideStiffness
            }

            // Re-pin after each pass — bend / distance corrections may have
            // nudged the dragged segment, and we want it locked to the cursor.
            state.positions[dragIdx] = target
        }

        physics = state

        // 3. Write back to segments and recompute tangents (same smoothing
        //    window as `rebuildSegments`).
        for i in 0..<n {
            segments[i].position = state.positions[i]
        }
        head = state.positions[0]
        for i in 0..<segments.count {
            let lo = max(0, i - 3)
            let hi = min(segments.count - 1, i + 3)
            let a = segments[lo].position
            let b = segments[hi].position
            segments[i].tangent = atan2(a.y - b.y, a.x - b.x)
        }
    }

    /// Post-release glide. Same constraint solve as `tickDragging` (length +
    /// bend + wide-stencil smoothing) but with no pinned segment and no
    /// gravity, just per-frame velocity damping representing surface friction.
    /// Body translates as a coherent unit with shape preserved, slowing to a
    /// halt — at which point control passes back to the AI.
    private func tickSliding(dt: TimeInterval) {
        guard var state = physics else { finishGlide(); return }
        let n = state.positions.count
        guard n >= 2 else { finishGlide(); return }

        // 1. Verlet integration. No gravity (flat-plane slide). Heavy
        //    friction — the snake should feel weighty, decelerating quickly
        //    rather than gliding effortlessly. 0.82/frame ≈ 86%/sec speed
        //    loss, so a 500 px/s flick decays to <50 px/s in ~0.3 s.
        let damping: CGFloat = 0.82
        let maxStep: CGFloat = 80
        var sumSpeedSq: CGFloat = 0
        for i in 0..<n {
            let pos = state.positions[i]
            let prev = state.prevPositions[i]
            var vx = (pos.x - prev.x) * damping
            var vy = (pos.y - prev.y) * damping
            vx = max(-maxStep, min(maxStep, vx))
            vy = max(-maxStep, min(maxStep, vy))
            sumSpeedSq += vx * vx + vy * vy
            state.prevPositions[i] = pos
            state.positions[i] = CGPoint(x: pos.x + vx, y: pos.y + vy)
        }

        // 2. Constraint solve. Distance constraints stay strong (body must
        //    keep its length), but bend stiffness is dialed *way* down vs.
        //    drag mode so the body flops like a ragdoll instead of holding
        //    a rigid pose during the throw — segments swing against their
        //    own inertia, the body trails the grip, the tail whips around.
        let iterations = 14
        let bendStiffness: CGFloat = 0.08
        let wideStiffness: CGFloat = 0.05
        let widePad = 4
        for _ in 0..<iterations {
            for i in 0..<(n - 1) {
                let a = state.positions[i]
                let b = state.positions[i + 1]
                let dx = b.x - a.x, dy = b.y - a.y
                let dist = max(0.0001, sqrt(dx * dx + dy * dy))
                let rest = state.restLengths[i]
                let diff = (dist - rest) / dist
                state.positions[i].x += dx * diff * 0.5
                state.positions[i].y += dy * diff * 0.5
                state.positions[i + 1].x -= dx * diff * 0.5
                state.positions[i + 1].y -= dy * diff * 0.5
            }
            for i in 1..<(n - 1) {
                let a = state.positions[i - 1]
                let b = state.positions[i + 1]
                let mid = CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
                let p = state.positions[i]
                state.positions[i].x = p.x + (mid.x - p.x) * bendStiffness
                state.positions[i].y = p.y + (mid.y - p.y) * bendStiffness
            }
            for i in widePad..<(n - widePad) {
                let a = state.positions[i - widePad]
                let b = state.positions[i + widePad]
                let mid = CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
                let p = state.positions[i]
                state.positions[i].x = p.x + (mid.x - p.x) * wideStiffness
                state.positions[i].y = p.y + (mid.y - p.y) * wideStiffness
            }
        }

        physics = state
        for i in 0..<n {
            segments[i].position = state.positions[i]
        }
        head = state.positions[0]
        for i in 0..<segments.count {
            let lo = max(0, i - 3)
            let hi = min(segments.count - 1, i + 3)
            let a = segments[lo].position
            let b = segments[hi].position
            segments[i].tangent = atan2(a.y - b.y, a.x - b.x)
        }

        // 3. End conditions: time cap reached, or motion has decayed below
        //    the threshold where AI motion would dwarf the slide anyway.
        //    Higher cutoff than before (60 px/s) so the snake doesn't keep
        //    creeping after the obvious "throw" energy is spent.
        let avgSpeedPerFrame = sqrt(sumSpeedSq / CGFloat(n))
        let avgSpeedPxSec = avgSpeedPerFrame / max(CGFloat(dt), 0.0001)
        let timeUp = (slideEndsAt.map { Date() >= $0 } ?? true)
        if timeUp || avgSpeedPxSec < 60 {
            finishGlide()
        }
    }

    /// Common cleanup path for "drag/glide is over → resume AI". Captures the
    /// current pose into the head-trail and re-derives the heading from the
    /// segment chain so locomotion picks up smoothly.
    private func finishGlide() {
        slideEndsAt = nil
        physics = nil
        rebuildTrailFromSegments()
        if segments.count >= 2 {
            let s0 = segments[0].position
            let s1 = segments[1].position
            headingBase = atan2(s0.y - s1.y, s0.x - s1.x)
            goalHeading = headingBase
            head = s0
        }
        nextDecisionAt = .distantPast
        pauseUntil = .distantPast
        let resumeSpeed = CGFloat.random(in: 70...90)
        targetSpeed = resumeSpeed
        speed = resumeSpeed
    }

    /// Reconstructs the head-trail from the current segment chain. Called at
    /// drag end so the AI's `rebuildSegments` can resume from the post-drag
    /// pose without the body snapping back to the pre-drag silhouette.
    private func rebuildTrailFromSegments() {
        guard segments.count >= 2 else { return }
        var dense: [CGPoint] = []
        dense.reserveCapacity(trailCapacity)
        dense.append(segments[0].position)
        for i in 0..<(segments.count - 1) {
            let a = segments[i].position
            let b = segments[i + 1].position
            let dist = hypot(b.x - a.x, b.y - a.y)
            let steps = max(1, Int(dist / trailEntryStep))
            for j in 1...steps {
                let t = CGFloat(j) / CGFloat(steps)
                dense.append(CGPoint(x: a.x + (b.x - a.x) * t,
                                     y: a.y + (b.y - a.y) * t))
            }
        }
        // Pad past the tail along the last direction so trail length stays
        // above the buffer's expected capacity.
        if dense.count >= 2 {
            let p1 = dense[dense.count - 2]
            let p2 = dense[dense.count - 1]
            let mag = max(0.001, hypot(p2.x - p1.x, p2.y - p1.y))
            let stepX = (p2.x - p1.x) / mag * trailEntryStep
            let stepY = (p2.y - p1.y) / mag * trailEntryStep
            while dense.count < trailCapacity {
                let last = dense[dense.count - 1]
                dense.append(CGPoint(x: last.x + stepX, y: last.y + stepY))
            }
        }
        trail = dense
    }
}

// MARK: - Snake view

final class SnakeView: NSView {
    /// Snake to render — the controller swaps in a fresh one per tick. Drawing
    /// reads `segments` and converts global screen coords to view-local.
    var snake: Snake?
    /// Origin of the view in global screen coords (= window.frame.origin). The
    /// controller updates this each tick so segment positions can be mapped
    /// into the view's local coordinate system.
    var viewOriginInScreen: CGPoint = .zero

    override var isFlipped: Bool { false }
    /// True so a click on the snake's body is delivered even when our window is
    /// not the key window (we never become key — see `SnakeWindow`).
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Returns self only if the click point lands on a body segment, so empty
    /// regions of the (transparent) window keep passing clicks through. The
    /// controller also toggles the parent window's `ignoresMouseEvents` based
    /// on cursor-vs-body so the click reaches us in the first place — see
    /// `SnakeController.updateInteractivity`.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let snake = snake else { return nil }
        let screenPoint = CGPoint(x: viewOriginInScreen.x + point.x,
                                  y: viewOriginInScreen.y + point.y)
        return snake.hitSegmentIndex(atScreen: screenPoint) != nil ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let snake = snake else { return }
        let screen = NSEvent.mouseLocation
        guard let idx = snake.hitSegmentIndex(atScreen: screen) else { return }
        snake.beginDrag(segmentIndex: idx, atScreenPoint: screen)
    }

    override func mouseDragged(with event: NSEvent) {
        snake?.updateDrag(toScreenPoint: NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        snake?.endDrag()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    private func toLocal(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - viewOriginInScreen.x, y: p.y - viewOriginInScreen.y)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let snake = snake, let ctx = NSGraphicsContext.current else { return }
        ctx.imageInterpolation = .high
        ctx.shouldAntialias = true

        let style = snake.style
        let segs = snake.segments
        guard segs.count >= 4 else { return }

        let outline = style.baseColor.shadow(withLevel: 0.55) ?? .black
        let highlight = style.baseColor.highlight(withLevel: 0.35) ?? style.baseColor

        // Pass 1: outline ribbon — same shape as the body but slightly inflated
        // so a thin dark border peeks out at the body's edges.
        let outlinePath = buildBodyRibbon(segs: segs, from: 0, through: segs.count - 1, padding: 1.4)
        outline.setFill()
        outlinePath.fill()

        // Pass 2: body fill. For banded patterns we paint per-section ribbons in
        // alternating colours; everything else is one big base-colour ribbon.
        if case .bands = style.pattern {
            drawBandedBody(segs: segs, style: style)
        } else {
            let bodyPath = buildBodyRibbon(segs: segs, from: 0, through: segs.count - 1, padding: 0)
            style.baseColor.setFill()
            bodyPath.fill()
        }

        // Pass 3 + 4: pattern overlays + dorsal sheen — clip everything to the
        // body silhouette so accents never bleed past the snake's edge.
        let bodyPath = buildBodyRibbon(segs: segs, from: 0, through: segs.count - 1, padding: 0)
        NSGraphicsContext.saveGraphicsState()
        bodyPath.setClip()
        drawPatternOverlay(segs: segs, style: style)
        drawDorsalSheen(segs: segs, highlight: highlight)
        NSGraphicsContext.restoreGraphicsState()

        // Pass 5: eyes (drawn unclipped so they always appear crisp on the head).
        drawEyes(head: segs[0])
    }

    // MARK: ribbon construction

    /// Builds a closed body polygon between two segment indices.
    ///
    /// Each segment contributes two perimeter points (left + right edges,
    /// `radius + padding` away from the centerline along the segment tangent's
    /// perpendicular). The right/left edge sequences are interpolated with
    /// Catmull-Rom-derived cubic Beziers so the silhouette is mathematically
    /// smooth instead of a chain of straight segments. Head end (start == 0)
    /// gets a forward-facing arc cap, tail end (through == count-1) gets a
    /// rounded arc cap; partial sections (used for bands) close with a flat
    /// perpendicular cut.
    private func buildBodyRibbon(segs: [SnakeSegment], from start: Int, through end: Int,
                                 padding: CGFloat) -> NSBezierPath {
        // Pre-compute right and left perimeter points for the requested range.
        var rightPts: [CGPoint] = []
        var leftPts: [CGPoint] = []
        rightPts.reserveCapacity(end - start + 1)
        leftPts.reserveCapacity(end - start + 1)
        for i in start...end {
            let s = segs[i]
            let p = toLocal(s.position)
            let r = s.radius + padding
            let perpRight = s.tangent - .pi / 2
            let perpLeft = s.tangent + .pi / 2
            rightPts.append(NSPoint(x: p.x + cos(perpRight) * r, y: p.y + sin(perpRight) * r))
            leftPts.append(NSPoint(x: p.x + cos(perpLeft) * r, y: p.y + sin(perpLeft) * r))
        }

        let path = NSBezierPath()
        path.move(to: rightPts[0])

        // Right edge — head to tail.
        SnakeView.appendCatmullRom(to: path, points: rightPts)

        // Tail end cap.
        if end == segs.count - 1 {
            let s = segs[end]
            let p = toLocal(s.position)
            let r = s.radius + padding
            // Arc from right-perp around through tangent+π (behind the tail) to
            // left-perp. NSBezierPath sweeps clockwise (decreasing angles); the
            // "via behind" path requires going through the ±180° wrap, so we
            // request clockwise:true.
            let startDeg = (s.tangent - .pi / 2) * 180 / .pi
            let endDeg = (s.tangent + .pi / 2) * 180 / .pi
            path.appendArc(withCenter: p, radius: r,
                           startAngle: startDeg, endAngle: endDeg,
                           clockwise: true)
        } else {
            // Section cut — straight perpendicular line over to the left edge.
            path.line(to: leftPts.last!)
        }

        // Left edge — tail back to head.
        SnakeView.appendCatmullRom(to: path, points: leftPts.reversed())

        // Head end cap.
        if start == 0 {
            let s = segs[0]
            let p = toLocal(s.position)
            let r = s.radius + padding
            // Arc from left-perp through tangent (forward) to right-perp.
            // Decreasing angles, no wrap → clockwise:true.
            let startDeg = (s.tangent + .pi / 2) * 180 / .pi
            let endDeg = (s.tangent - .pi / 2) * 180 / .pi
            path.appendArc(withCenter: p, radius: r,
                           startAngle: startDeg, endAngle: endDeg,
                           clockwise: true)
        }

        path.close()
        return path
    }

    /// Appends a smooth Catmull-Rom-derived curve through `points`, starting
    /// from the path's current point (which must equal `points[0]`). End points
    /// are duplicated to handle open boundaries (no phantom extrapolation).
    static func appendCatmullRom(to path: NSBezierPath, points: [CGPoint],
                                 tension: CGFloat = 0.5) {
        guard points.count >= 2 else { return }
        let alpha = tension / 6.0
        let arr = Array(points)
        for i in 0..<(arr.count - 1) {
            let p0 = i > 0 ? arr[i - 1] : arr[i]
            let p1 = arr[i]
            let p2 = arr[i + 1]
            let p3 = i < arr.count - 2 ? arr[i + 2] : arr[i + 1]
            let cp1 = NSPoint(x: p1.x + (p2.x - p0.x) * alpha,
                              y: p1.y + (p2.y - p0.y) * alpha)
            let cp2 = NSPoint(x: p2.x - (p3.x - p1.x) * alpha,
                              y: p2.y - (p3.y - p1.y) * alpha)
            path.curve(to: p2, controlPoint1: cp1, controlPoint2: cp2)
        }
    }

    // MARK: patterns

    /// Solid pattern, with bands handled here as alternating ribbon sections so
    /// each band has clean perpendicular edges that follow body curvature.
    private func drawBandedBody(segs: [SnakeSegment], style: SnakeStyle) {
        let bandSize = 5
        var i = 0
        var alt = false
        while i < segs.count {
            let end = min(i + bandSize, segs.count - 1)
            let path = buildBodyRibbon(segs: segs, from: i, through: end, padding: 0)
            (alt ? style.secondaryColor : style.baseColor).setFill()
            path.fill()
            if end == segs.count - 1 { break }
            i = end
            alt.toggle()
        }
    }

    /// Pattern accents drawn on top of the body fill (everything except bands,
    /// which are baked into the fill itself). Caller clips to the body shape.
    private func drawPatternOverlay(segs: [SnakeSegment], style: SnakeStyle) {
        switch style.pattern {
        case .solid, .bands:
            return
        case .dorsalStripe:
            // Inner ribbon — same path-following shape, ~38% body radius — gives
            // a soft lighter line down the spine that follows every curve.
            let stripe = buildBodyRibbon(segs: segs, from: 0, through: segs.count - 1,
                                         padding: 0)
            // Re-render as a narrower ribbon by scaling each radius. Easier: build
            // a shrunk version directly.
            _ = stripe // (full ribbon used as clip outside; we draw a narrower one)
            let narrowed = buildScaledRibbon(segs: segs, radiusScale: 0.42)
            style.secondaryColor.setFill()
            narrowed.fill()
        case .blotches:
            // Soft irregular blobs every ~4 segments. Ellipses oriented to the
            // local tangent so they match body curvature instead of looking
            // like floating stickers.
            for (idx, seg) in segs.enumerated() {
                guard idx > 2, idx < segs.count - 3, idx % 4 == 0 else { continue }
                drawOrientedEllipse(at: seg.position, tangent: seg.tangent,
                                    along: seg.radius * 1.3,
                                    across: seg.radius * 0.85,
                                    color: style.secondaryColor)
            }
        case .checker:
            // Diamonds along the spine, alternating sides every step.
            for (idx, seg) in segs.enumerated() {
                guard idx > 2, idx < segs.count - 3, idx % 3 == 0 else { continue }
                let side: CGFloat = (idx / 3) % 2 == 0 ? -1 : 1
                let perp = seg.tangent + .pi / 2
                let off = seg.radius * 0.30 * side
                let p = toLocal(seg.position)
                let cx = p.x + cos(perp) * off
                let cy = p.y + sin(perp) * off
                let r = seg.radius * 0.55
                let path = NSBezierPath()
                path.move(to: NSPoint(x: cx, y: cy + r))
                path.line(to: NSPoint(x: cx + r * 0.85, y: cy))
                path.line(to: NSPoint(x: cx, y: cy - r))
                path.line(to: NSPoint(x: cx - r * 0.85, y: cy))
                path.close()
                style.secondaryColor.setFill()
                path.fill()
            }
        }
    }

    /// Builds a thinner version of the full body ribbon by scaling each
    /// segment's effective radius. Used for the dorsal-stripe accent.
    private func buildScaledRibbon(segs: [SnakeSegment], radiusScale: CGFloat) -> NSBezierPath {
        // Synthesize scaled segments and re-run the same builder so the head /
        // tail caps stay properly rounded even when narrower.
        let scaled = segs.map { SnakeSegment(position: $0.position,
                                              radius: $0.radius * radiusScale,
                                              tangent: $0.tangent,
                                              arcLength: $0.arcLength) }
        return buildBodyRibbon(segs: scaled, from: 0, through: scaled.count - 1, padding: 0)
    }

    /// Single off-center highlight ribbon — gives the body a top-lit cylindrical
    /// shading without per-segment artefacts.
    private func drawDorsalSheen(segs: [SnakeSegment], highlight: NSColor) {
        // Build a narrow ribbon offset slightly perpendicular to the tangent so
        // the highlight sits on one consistent "side" of the body (the snake's
        // dorsal surface in our top-down view).
        let offsetSegs: [SnakeSegment] = segs.map { s in
            let perp = s.tangent + .pi / 2
            let off = s.radius * 0.30
            let p = NSPoint(x: s.position.x + cos(perp) * off,
                            y: s.position.y + sin(perp) * off)
            return SnakeSegment(position: p, radius: s.radius * 0.32,
                                tangent: s.tangent, arcLength: s.arcLength)
        }
        let path = buildBodyRibbon(segs: offsetSegs, from: 0, through: offsetSegs.count - 1,
                                   padding: 0)
        highlight.withAlphaComponent(0.30).setFill()
        path.fill()
    }

    // MARK: head + helpers

    /// Filled ellipse oriented along a tangent direction. Used for blotches.
    private func drawOrientedEllipse(at center: CGPoint, tangent: CGFloat,
                                     along: CGFloat, across: CGFloat, color: NSColor) {
        let local = toLocal(center)
        NSGraphicsContext.saveGraphicsState()
        let xform = NSAffineTransform()
        xform.translateX(by: local.x, yBy: local.y)
        xform.rotate(byRadians: tangent)
        xform.concat()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: -along, y: -across,
                                    width: 2 * along, height: 2 * across)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Two small eyes near the front of the head, oriented to its tangent.
    /// The head silhouette itself is part of the body ribbon (the rounded front
    /// arc), so we only need to add eyes.
    private func drawEyes(head: SnakeSegment) {
        let pos = toLocal(head.position)
        NSGraphicsContext.saveGraphicsState()
        let xform = NSAffineTransform()
        xform.translateX(by: pos.x, yBy: pos.y)
        xform.rotate(byRadians: head.tangent)
        xform.concat()

        let eyeR: CGFloat = max(0.9, head.radius * 0.22)
        let eyeForward = head.radius * 0.30   // toward front of head
        let eyeSide = head.radius * 0.55      // off the centerline

        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: eyeForward - eyeR, y: eyeSide - eyeR,
                                    width: 2 * eyeR, height: 2 * eyeR)).fill()
        NSBezierPath(ovalIn: NSRect(x: eyeForward - eyeR, y: -eyeSide - eyeR,
                                    width: 2 * eyeR, height: 2 * eyeR)).fill()

        // Glints — tiny white dots biased forward-and-up from each eye.
        let gR = eyeR * 0.45
        NSColor(white: 1.0, alpha: 0.9).setFill()
        NSBezierPath(ovalIn: NSRect(x: eyeForward - gR + eyeR * 0.20,
                                    y: eyeSide - gR + eyeR * 0.20,
                                    width: 2 * gR, height: 2 * gR)).fill()
        NSBezierPath(ovalIn: NSRect(x: eyeForward - gR + eyeR * 0.20,
                                    y: -eyeSide - gR + eyeR * 0.20,
                                    width: 2 * gR, height: 2 * gR)).fill()

        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - Snake controller

/// Borderless window that never becomes key — we want clicks on the snake's
/// body to be received (via `acceptsFirstMouse`) without stealing focus from
/// whatever the user is currently working in.
final class SnakeWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class SnakeController: NSObject {
    var window: SnakeWindow!
    var view: SnakeView!
    var snake: Snake!

    private let queue = DispatchQueue.main
    private var tickTimer: DispatchSourceTimer?
    private var lastTick: Date = Date()
    /// Cached so we only call setIgnoresMouseEvents when the value flips.
    private var currentIgnoresMouse: Bool = true

    /// Window side length — generous enough to never clip the snake at any
    /// reasonable curvature. Scales with the style's body length.
    private var windowSide: CGFloat { snake.style.length * 3 + 80 }

    func start(at point: NSPoint? = nil, style: SnakeStyle? = nil) {
        let chosenStyle = style ?? snakeStyles.randomElement()!
        let spawnPoint = point ?? defaultSpawn()
        let heading = CGFloat.random(in: 0..<(2 * .pi))
        snake = Snake(style: chosenStyle, head: spawnPoint, heading: heading)

        let side = windowSide
        let originX = spawnPoint.x - side / 2
        let originY = spawnPoint.y - side / 2

        window = SnakeWindow(
            contentRect: NSRect(x: originX, y: originY, width: side, height: side),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // We selectively turn this off in `tick()` when the cursor is over the
        // snake's body, so the user can grab and drag any joint while empty
        // regions of the (transparent) window keep falling through to the
        // desktop / windows below.
        window.ignoresMouseEvents = true
        currentIgnoresMouse = true
        window.animationBehavior = .none
        window.level = AppState.shared.displayMode.chickLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        view = SnakeView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        view.snake = snake
        view.viewOriginInScreen = window.frame.origin
        window.contentView = view
        window.orderFrontRegardless()

        startTickLoop()
    }

    /// Picks a random spot on the user's main screen for unprovoked spawns.
    private func defaultSpawn() -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let vf = screen.visibleFrame.insetBy(dx: 80, dy: 80)
        return NSPoint(x: CGFloat.random(in: vf.minX...vf.maxX),
                       y: CGFloat.random(in: vf.minY...vf.maxY))
    }

    func close() {
        tickTimer?.cancel()
        tickTimer = nil
        window?.orderOut(nil)
    }

    func despawnNow() {
        close()
        AppState.shared.removeSnake(self)
    }

    func applyDisplayMode() {
        window?.level = AppState.shared.displayMode.chickLevel
    }

    /// Swap the snake's visual style at runtime. Resizes the window if the new
    /// style's body length differs from the current one so the body always has
    /// room to render at any curvature; window stays centered on the current
    /// head so the snake doesn't appear to teleport.
    func applyStyle(_ newStyle: SnakeStyle) {
        snake.style = newStyle

        let newSide = newStyle.length * 3 + 80
        if abs(newSide - window.frame.width) > 0.5 {
            let head = snake.head
            let newOrigin = NSPoint(x: head.x - newSide / 2, y: head.y - newSide / 2)
            window.setFrame(NSRect(x: newOrigin.x, y: newOrigin.y,
                                   width: newSide, height: newSide),
                            display: false)
            view.frame = NSRect(x: 0, y: 0, width: newSide, height: newSide)
            view.viewOriginInScreen = window.frame.origin
        }
        view.needsDisplay = true
    }

    private func startTickLoop() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        let interval = 1.0 / 60.0   // 60Hz feels noticeably smoother than 30 here
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(2))
        lastTick = Date()
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        tickTimer = t
    }

    private func tick() {
        let now = Date()
        let dt = max(0.001, min(0.1, now.timeIntervalSince(lastTick)))
        lastTick = now
        snake.tick(dt: dt)

        // Window movement strategy: keep the window mostly still and let the
        // snake glide *within* the window via the view's redraw. setFrameOrigin
        // is expensive — calling it every frame at 60 Hz forces the macOS
        // compositor to recomposite the desktop on each tick, which can produce
        // sub-frame stutter perceived as "blocky" motion. Recentre only when
        // the body's anchor point has drifted a meaningful fraction of the
        // window's half-width.
        //
        // While dragging, the natural anchor is the body's centroid (so the
        // dragged joint and the rest of the rope both stay in the window's
        // drawable area, even when the head dangles far below the cursor).
        let side = window.frame.width
        let anchor = currentAnchor()
        let center = NSPoint(x: window.frame.origin.x + side / 2,
                             y: window.frame.origin.y + side / 2)
        let driftX = anchor.x - center.x
        let driftY = anchor.y - center.y
        // Tighter threshold during physics phases (drag + post-release glide)
        // so the body doesn't crawl off-window when the user yanks the cursor
        // to a screen edge or the snake slides far on momentum.
        let inPhysics = (snake.dragInfo != nil) || (snake.slideEndsAt != nil)
        let recentreThreshold = side * (inPhysics ? 0.15 : 0.30)
        if abs(driftX) > recentreThreshold || abs(driftY) > recentreThreshold {
            let target = NSPoint(x: anchor.x - side / 2, y: anchor.y - side / 2)
            window.setFrameOrigin(target)
            view.viewOriginInScreen = window.frame.origin
        }

        updateInteractivity()
        view.needsDisplay = true
    }

    /// Anchor point used for window centring. Head while AI-driven; body
    /// centroid while dragging or sliding so the rope stays visible.
    private func currentAnchor() -> CGPoint {
        if snake.dragInfo != nil || snake.slideEndsAt != nil {
            let segs = snake.segments
            guard !segs.isEmpty else { return snake.head }
            var sx: CGFloat = 0, sy: CGFloat = 0
            for s in segs { sx += s.position.x; sy += s.position.y }
            return CGPoint(x: sx / CGFloat(segs.count),
                           y: sy / CGFloat(segs.count))
        }
        return snake.head
    }

    /// Toggle `ignoresMouseEvents` per frame so the window only swallows
    /// clicks when the cursor is actually over the snake's body — clicks on
    /// transparent regions still pass through. Stays interactive for the full
    /// duration of an in-progress drag regardless of cursor position.
    private func updateInteractivity() {
        let cursor = NSEvent.mouseLocation
        let interactive = (snake.dragInfo != nil) ||
                          (snake.hitSegmentIndex(atScreen: cursor) != nil)
        let newIgnores = !interactive
        if newIgnores != currentIgnoresMouse {
            window.ignoresMouseEvents = newIgnores
            currentIgnoresMouse = newIgnores
        }
    }
}

// MARK: - App delegate / status bar menu

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var statusItem: NSStatusItem!

    var spawnMenuItem: NSMenuItem!
    var despawnMenuItem: NSMenuItem!
    var spawnBunnyMenuItem: NSMenuItem!
    var despawnBunnyMenuItem: NSMenuItem!
    var spawnSnakeMenuItem: NSMenuItem!
    var despawnSnakeMenuItem: NSMenuItem!
    var randomizeSnakesMenuItem: NSMenuItem!
    var islandMenuItem: NSMenuItem!
    var desktopModeItem: NSMenuItem!
    var floatingModeItem: NSMenuItem!
    var chickStyleMenuItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = true

        // Spawn the seed chick. No longer marked immortal — manual despawn can
        // take the population to zero, but the "last chick stays out of the
        // coop" rule keeps a visible chick alive while one remains.
        AppState.shared.spawnChick(tint: chickTints[0], isOriginal: true)
        // Seed a bunny too if any bunny art is on disk; silently skip
        // otherwise so the app still runs before bunny assets are added.
        if Assets.shared.anyBunnyArtAvailable {
            AppState.shared.spawnBunny(tint: chickTints[0])
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let img = loadStatusBarIcon() {
            statusItem.button?.image = img
            statusItem.button?.imagePosition = .imageOnly
            statusItem.button?.title = ""
        } else {
            statusItem.button?.title = "🐤"
        }

        let menu = NSMenu()

        spawnMenuItem = NSMenuItem(title: "Spawn Chick", action: #selector(spawnRandomChick), keyEquivalent: "n")
        spawnMenuItem.target = self
        menu.addItem(spawnMenuItem)

        despawnMenuItem = NSMenuItem(title: "Despawn Chick", action: #selector(despawnOneChick), keyEquivalent: "d")
        despawnMenuItem.target = self
        menu.addItem(despawnMenuItem)

        menu.addItem(NSMenuItem.separator())

        spawnBunnyMenuItem = NSMenuItem(title: "Spawn Bunny", action: #selector(spawnBunnyAction), keyEquivalent: "b")
        spawnBunnyMenuItem.target = self
        menu.addItem(spawnBunnyMenuItem)

        despawnBunnyMenuItem = NSMenuItem(title: "Despawn Bunny", action: #selector(despawnOneBunnyAction), keyEquivalent: "")
        despawnBunnyMenuItem.target = self
        menu.addItem(despawnBunnyMenuItem)

        menu.addItem(NSMenuItem.separator())

        spawnSnakeMenuItem = NSMenuItem(title: "Spawn Snake", action: #selector(spawnSnakeAction), keyEquivalent: "s")
        spawnSnakeMenuItem.target = self
        menu.addItem(spawnSnakeMenuItem)

        despawnSnakeMenuItem = NSMenuItem(title: "Despawn Snake", action: #selector(despawnOneSnakeAction), keyEquivalent: "")
        despawnSnakeMenuItem.target = self
        menu.addItem(despawnSnakeMenuItem)

        randomizeSnakesMenuItem = NSMenuItem(title: "Randomize Snakes", action: #selector(randomizeSnakesAction), keyEquivalent: "r")
        randomizeSnakesMenuItem.target = self
        menu.addItem(randomizeSnakesMenuItem)

        menu.addItem(NSMenuItem.separator())

        islandMenuItem = NSMenuItem(title: "Show Chicken Island", action: #selector(toggleIsland), keyEquivalent: "i")
        islandMenuItem.target = self
        menu.addItem(islandMenuItem)

        menu.addItem(NSMenuItem.separator())

        let displayHeader = NSMenuItem(title: "Display Mode", action: nil, keyEquivalent: "")
        displayHeader.isEnabled = false
        menu.addItem(displayHeader)

        desktopModeItem = NSMenuItem(title: "On Desktop (below windows)",
                                     action: #selector(setDesktopMode), keyEquivalent: "")
        desktopModeItem.target = self
        menu.addItem(desktopModeItem)

        floatingModeItem = NSMenuItem(title: "Above All Windows",
                                      action: #selector(setFloatingMode), keyEquivalent: "")
        floatingModeItem.target = self
        menu.addItem(floatingModeItem)

        menu.addItem(NSMenuItem.separator())

        // Chick Style as a submenu (cleaner with 8+ options).
        let styleParent = NSMenuItem(title: "Chick Style", action: nil, keyEquivalent: "")
        let styleSubmenu = NSMenu()
        styleParent.submenu = styleSubmenu
        menu.addItem(styleParent)

        chickStyleMenuItems = []
        for style in chickStyles {
            let item = NSMenuItem(title: style.menuTitle,
                                  action: #selector(setChickStyle(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = style.id
            styleSubmenu.addItem(item)
            chickStyleMenuItems.append(item)
        }

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit Chick", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        refreshMenuChecks()
    }

    /// Loads MenuIcon (preferring @2x for retina) into a properly-sized template-friendly NSImage.
    private func loadStatusBarIcon() -> NSImage? {
        guard let res = Bundle.main.resourceURL else { return nil }
        let one = res.appendingPathComponent("MenuIcon.png")
        let two = res.appendingPathComponent("MenuIcon@2x.png")
        let img = NSImage()
        if FileManager.default.fileExists(atPath: one.path),
           let r = NSImage(contentsOf: one)?.representations.first {
            img.addRepresentation(r)
        }
        if FileManager.default.fileExists(atPath: two.path),
           let r = NSImage(contentsOf: two)?.representations.first {
            // Mark @2x rep so AppKit chooses it on retina.
            r.size = NSSize(width: 22, height: 22)
            img.addRepresentation(r)
        }
        guard !img.representations.isEmpty else { return nil }
        img.size = NSSize(width: 22, height: 22)
        img.isTemplate = false // keep the colorful chick — don't tint to monochrome
        return img
    }

    private func refreshMenuChecks() {
        islandMenuItem.state = (AppState.shared.island != nil) ? .on : .off
        islandMenuItem.title = (AppState.shared.island != nil) ? "Hide Chicken Island" : "Show Chicken Island"
        desktopModeItem.state = (AppState.shared.displayMode == .desktop) ? .on : .off
        floatingModeItem.state = (AppState.shared.displayMode == .floating) ? .on : .off
        for item in chickStyleMenuItems {
            let id = item.representedObject as? String ?? ""
            item.state = (id == AppState.shared.currentChickStyle.id) ? .on : .off
        }
    }

    /// Disable despawn items when their species is empty; also gate Spawn
    /// Bunny on whether any bunny art has been added to the project yet.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem === despawnMenuItem {
            return !AppState.shared.chicks.isEmpty
        }
        if menuItem === spawnBunnyMenuItem {
            return Assets.shared.anyBunnyArtAvailable
        }
        if menuItem === despawnBunnyMenuItem {
            return !AppState.shared.bunnies.isEmpty
        }
        if menuItem === despawnSnakeMenuItem {
            return !AppState.shared.snakes.isEmpty
        }
        if menuItem === randomizeSnakesMenuItem {
            return !AppState.shared.snakes.isEmpty
        }
        return true
    }

    @objc func spawnRandomChick() {
        AppState.shared.spawnChick()
    }

    @objc func despawnOneChick() {
        _ = AppState.shared.despawnOneChick()
    }

    @objc func spawnBunnyAction() {
        AppState.shared.spawnBunny()
    }

    @objc func despawnOneBunnyAction() {
        _ = AppState.shared.despawnOneBunny()
    }

    @objc func spawnSnakeAction() {
        AppState.shared.spawnSnake()
    }

    @objc func despawnOneSnakeAction() {
        _ = AppState.shared.despawnOneSnake()
    }

    @objc func randomizeSnakesAction() {
        _ = AppState.shared.randomizeSnakes()
    }

    @objc func toggleIsland() {
        AppState.shared.toggleIsland()
        refreshMenuChecks()
    }

    @objc func setDesktopMode() {
        AppState.shared.displayMode = .desktop
        refreshMenuChecks()
    }

    @objc func setFloatingMode() {
        AppState.shared.displayMode = .floating
        refreshMenuChecks()
    }

    @objc func setChickStyle(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        AppState.shared.currentChickStyle = chickStyle(forID: id)
        refreshMenuChecks()
    }

    @objc func quit() { NSApp.terminate(nil) }
}

// MARK: - main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

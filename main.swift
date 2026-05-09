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

// MARK: - Asset registry

final class Assets {
    static let shared = Assets()

    /// Single-image anime island + coop (replaces the legacy pixel-art pair).
    let coopImage: NSImage

    /// Base spritesheet per style — loaded lazily on first request.
    private var chickSheetCache: [String: NSImage] = [:]
    /// Tinted spritesheet per (style, tint) — also lazy.
    private var tintedSheetCache: [String: NSImage] = [:]

    private static func load(_ name: String, fallback: String) -> NSImage {
        if let p = Bundle.main.path(forResource: name, ofType: "png"),
           let img = NSImage(contentsOfFile: p) { return img }
        if let img = NSImage(contentsOfFile: fallback) { return img }
        NSLog("Missing asset: \(name)")
        exit(1)
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
    var island: IslandController?

    private init() {}

    func applyDisplayMode() {
        for c in chicks { c.applyDisplayMode() }
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
            }
        }
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

    /// Removes one (non-original) chick on demand, never dropping below the original chick.
    /// Returns true if a chick was despawned. The most recently spawned candidate goes first.
    @discardableResult
    func despawnOneChick() -> Bool {
        for c in chicks.reversed() where !c.isOriginal {
            c.despawnNow()
            return true
        }
        return false
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
        SoundManager.shared.playRandomChirp()
    }

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
        // Spawn 1-3 chicks at random tints; tints distinct from one another when possible.
        let count = Int.random(in: 1...3)
        var pool = chickTints.shuffled()
        for _ in 0..<count {
            if pool.isEmpty { pool = chickTints.shuffled() }
            let tint = pool.removeFirst()
            let door = houseDoorScreenPoint()
            // small random offset so they don't stack on top of each other
            let dx = CGFloat.random(in: -10...10)
            let dy = CGFloat.random(in: -4...4)
            AppState.shared.spawnChick(at: NSPoint(x: door.x + dx, y: door.y + dy), tint: tint)
        }
    }
}

// MARK: - App delegate / status bar menu

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var statusItem: NSStatusItem!

    var spawnMenuItem: NSMenuItem!
    var despawnMenuItem: NSMenuItem!
    var islandMenuItem: NSMenuItem!
    var desktopModeItem: NSMenuItem!
    var floatingModeItem: NSMenuItem!
    var chickStyleMenuItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = true

        // Spawn the original yellow chick (immortal, always visible).
        AppState.shared.spawnChick(tint: chickTints[0], isOriginal: true)

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

    /// Disable Despawn Chick when only the immortal original is left.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem === despawnMenuItem {
            return AppState.shared.chicks.contains { !$0.isOriginal }
        }
        return true
    }

    @objc func spawnRandomChick() {
        AppState.shared.spawnChick()
    }

    @objc func despawnOneChick() {
        _ = AppState.shared.despawnOneChick()
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

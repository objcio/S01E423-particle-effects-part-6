//

import SwiftUI

struct HeartParticle: Particle {
    var amplitude: Double
    var verticalDistance: Double
    var lifetime: TimeInterval = 1.5

    init() {
        amplitude = .random(in: -30...30)
        verticalDistance = .random(in: 50...90)
    }

    struct Value {
        var offset: CGSize
        var opacity: CGFloat
    }

    func value(at progress: Double) -> Value {
        let timeline = KeyframeTimeline(initialValue: Value(offset: .zero, opacity: 0)) {
            KeyframeTrack(\.offset.width) {
                CubicKeyframe(amplitude, duration: 0.2)
                CubicKeyframe(-amplitude * 0.8, duration: 0.3)
                CubicKeyframe(amplitude * 0.5, duration: 0.4)
            }
            KeyframeTrack(\.offset.height) {
                CubicKeyframe(-verticalDistance, duration: 1)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(1, duration: 0.2)
                CubicKeyframe(0, duration: 0.8)
            }
        }
        return timeline.value(progress: progress)
    }

    func draw(symbol: GraphicsContext.ResolvedSymbol, in context: inout GraphicsContext, progress: Double) {
        let value = self.value(at: progress)
        context.opacity = value.opacity
        context.translateBy(x: sin(progress * 2 * .pi) * amplitude, y: value.offset.height)
        context.draw(symbol, at: .zero)
    }
}
struct SprayParticle: Particle {
    var endOffset: CGSize
    var lifetime: TimeInterval = 1.5

    init() {
        let angle = Angle.degrees(.random(in: 0..<360))
        let length = Double.random(in: 25..<100)
        endOffset = CGSize(width: cos(angle.radians) * length, height: sin(angle.radians) * length)
    }

    struct Value {
        var offset: CGSize
        var opacity: CGFloat
        var angle: Angle = .zero
    }

    func value(at progress: Double) -> Value {
        let timeline = KeyframeTimeline(initialValue: Value(offset: .zero, opacity: 0)) {
            KeyframeTrack(\.offset) {
//                CubicKeyframe(endOffset * 0.5, duration: 0.3)
//                CubicKeyframe(endOffset * 0.2, duration: 0.2)
                CubicKeyframe(endOffset, duration: 1)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(1, duration: 0.2)
                CubicKeyframe(0, duration: 0.8)
            }
            KeyframeTrack(\.angle) {
                CubicKeyframe(.zero, duration: 0.7)
                CubicKeyframe(.degrees(45), duration: 0.3)
            }
        }
        return timeline.value(progress: progress)
    }

    func draw(symbol: GraphicsContext.ResolvedSymbol, in context: inout GraphicsContext, progress: Double) {
        let value = self.value(at: progress)
        context.opacity = value.opacity
        context.translateBy(x: value.offset.width, y: value.offset.height)
        context.rotate(by: value.angle)
        context.draw(symbol, at: .zero)
    }
}

protocol Particle {
    var lifetime: TimeInterval { get }
    func draw(symbol: GraphicsContext.ResolvedSymbol, in context: inout GraphicsContext, progress: Double)
}

final class ParticleState<P: Particle>: ObservableObject {
    @Published var isPaused = true

    var particles: [(particle: P, startTime: Date)] = [] {
        didSet {
            DispatchQueue.main.async {
                if oldValue.isEmpty != self.particles.isEmpty {
                    self.isPaused = self.particles.isEmpty
                }
            }
        }
    }
}

struct ParticleEffect<P: Particle, T: Equatable>: ViewModifier {
    var trigger: T
    var numberOfParticles = 30
    var makeParticle: () -> P
    @StateObject private var state = ParticleState<P>()

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: state.isPaused)) { timelineCtx in
            Canvas { context, size in
                let symbol = context.resolveSymbol(id: "particle")!
                context.translateBy(x: size.width/2, y: size.height/2)

                for (particle, particleStart) in state.particles {
                    guard timelineCtx.date >= particleStart else { continue }
                    let diff = timelineCtx.date.timeIntervalSince(particleStart)
                    let progress = diff/particle.lifetime
                    guard progress < 1 else { continue }
                    var copy = context
                    particle.draw(symbol: symbol, in: &copy, progress: progress)
                }
                state.particles.removeAll(where: { p, startDate in
                    startDate.addingTimeInterval(p.lifetime) <= timelineCtx.date
                })
            } symbols: {
                content.tag("particle")
            }
            .frame(width: 200, height: 200)
        }
        .onChange(of: trigger) {
            state.particles.append(contentsOf: (0..<numberOfParticles).map { _ in
                (particle: makeParticle(), startTime: .now.addingTimeInterval(.random(in: 0..<1)))
            })
        }
    }
}

extension View {
    func particleEffect<Trigger: Hashable, P: Particle>(trigger: Trigger, numberOfParticles: Int = 30, makeParticle: @escaping () -> P) -> some View {
        self.background {
            self.modifier(ParticleEffect(trigger: trigger, numberOfParticles: numberOfParticles, makeParticle: makeParticle))
        }
    }

    func sprayEffect<Trigger: Hashable>(trigger: Trigger) -> some View {
        self.particleEffect(trigger: trigger, makeParticle: { SprayParticle() })
    }
}

struct ContentView: View {
    @ScaledMetric var dividerHeight = 18
    @State private var trigger = 0
    @State private var heartTrigger = 0
    @State private var numberOfHeartParticles: CGFloat = 15

    var body: some View {
        VStack {
            Slider(value: $numberOfHeartParticles, in: 1...30)
            Button(action: {
                heartTrigger += 1
            }, label: {
                HStack {
                    Image(systemName: "heart.fill")
                        .particleEffect(trigger: heartTrigger, numberOfParticles: .init(numberOfHeartParticles), makeParticle: {
                            HeartParticle()
                        })
                    Divider()
                        .frame(height: dividerHeight)
                    Text("Like")
                }
                .contentShape(.rect)
            })
            Button(action: {
                trigger += 1
            }, label: {
                HStack {
                    Image(systemName: "star.fill")
                        .sprayEffect(trigger: trigger)
                    Divider()
                        .frame(height: dividerHeight)
                    Text("Favorite")
                }
                .contentShape(.rect)
            })
        }
        .buttonStyle(.link)
        .padding()
    }
}

#Preview {
    ContentView()
        .padding(50)
}

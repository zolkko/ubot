import SwiftUI


struct SpeedometerView: View {
    var speed: Float // 0...1
    var label: String

    private let startAngle = Angle(degrees: 135)
    private let endAngle = Angle(degrees: 405)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: size * 0.06)

                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: 0.75 * CGFloat(speed))
                    .stroke(
                        AngularGradient(colors: [.green, .yellow, .red], center: .center),
                        style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))
                    .animation(.easeOut(duration: 0.08), value: speed)

                Needle(angle: startAngle + (endAngle - startAngle) * CGFloat(speed))
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: size, height: size)
                    .animation(.easeOut(duration: 0.08), value: speed)

                Circle()
                    .fill(Color.primary)
                    .frame(width: size * 0.05, height: size * 0.05)

                VStack {
                    Spacer()
                    Text("\(Int(speed * 100))%")
                        .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: label)
                        .font(.system(size: size * 0.06))
                        .foregroundStyle(.secondary)
                    Spacer().frame(height: size * 0.12)
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

private struct Needle: Shape {
    var angle: Angle

    var animatableData: Double {
        get { angle.degrees }
        set { angle = .degrees(newValue) }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * 0.72
        let tip = CGPoint(
            x: center.x + radius * CGFloat(cos(angle.radians)),
            y: center.y + radius * CGFloat(sin(angle.radians))
        )
        var path = Path()
        path.move(to: center)
        path.addLine(to: tip)
        return path
    }
}

#Preview {
    SpeedometerView(speed: 0.65, label: "LEFT TRACK")
        .frame(width: 220, height: 220)
        .padding()
}

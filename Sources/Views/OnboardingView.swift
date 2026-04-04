import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                onboardingPage(
                    icon: "heart.text.square.fill",
                    iconColor: .red,
                    title: "欢迎使用血压管家",
                    subtitle: "轻松记录和追踪您的血压数据，守护您的心血管健康"
                )
                .tag(0)

                onboardingPage(
                    icon: "camera.fill",
                    iconColor: .accentColor,
                    title: "拍照即可识别",
                    subtitle: "对准血压计屏幕拍照，AI 自动识别读数，免去手动输入"
                )
                .tag(1)

                onboardingPage(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: "趋势分析与报告",
                    subtitle: "查看血压变化趋势，生成 PDF 报告，方便就医时展示给医生"
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: {
                if currentPage < 2 {
                    withAnimation { currentPage += 1 }
                } else {
                    hasCompletedOnboarding = true
                }
            }) {
                Text(currentPage < 2 ? "下一步" : "开始使用")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .accessibilityHint(currentPage < 2 ? "前往下一页" : "完成引导，进入应用")
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            if currentPage < 2 {
                Button("跳过") {
                    hasCompletedOnboarding = true
                }
                .foregroundColor(.secondary)
                .accessibilityHint("跳过引导，直接进入应用")
                .padding(.bottom, 24)
            } else {
                Spacer().frame(height: 52)
            }
        }
    }

    private func onboardingPage(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(iconColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)。\(subtitle)")
    }
}

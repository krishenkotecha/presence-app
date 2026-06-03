import SwiftUI

struct RootView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var selectedTab: AppTab = .home
    @State private var askQuerySeed = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(selectedTab: $selectedTab, askQuerySeed: $askQuerySeed)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            NavigationStack {
                SessionSetupView()
            }
            .tabItem {
                Label("Listen", systemImage: "waveform.and.mic")
            }
            .tag(AppTab.listen)

            NavigationStack {
                PatternsView()
            }
            .tabItem {
                Label("Patterns", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(AppTab.patterns)

            NavigationStack {
                AskView(querySeed: $askQuerySeed)
            }
            .tabItem {
                Label("Ask", systemImage: "sparkle.magnifyingglass")
            }
            .tag(AppTab.ask)
        }
        .tint(themeStore.current.accentSuccess)
    }
}

private enum AppTab: Hashable {
    case home
    case listen
    case patterns
    case ask
}

private enum HomeRoute: Hashable, Identifiable {
    case relationships

    var id: String {
        switch self {
        case .relationships: "relationships"
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var themeStore: ThemeStore
    @Binding var selectedTab: AppTab
    @Binding var askQuerySeed: String
    @State private var isMenuPresented = false
    @State private var route: HomeRoute?

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        greetingBlock
                        startListeningRow
                        todaysDiscoveryCard
                        askAnythingSection
                        recentTrendsSection
                        patternsToWatchSection
                        peopleStripSection
                        Spacer(minLength: max(36, proxy.size.height * 0.08))
                    }
                    .frame(maxWidth: 480, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            }
            .background(HomeBackdrop(theme: theme).ignoresSafeArea())
            .blur(radius: isMenuPresented ? 6 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isMenuPresented)

            if isMenuPresented {
                Color.black.opacity(0.14)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isMenuPresented = false
                    }

                SlideOutMenu(theme: theme, isPresented: $isMenuPresented)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .padding(.trailing, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 8) {
                    DialogueMark(theme: theme)
                    Text("Presence")
                        .font(.system(size: 24, weight: .bold, design: theme.displayDesign))
                        .foregroundStyle(theme.primaryText)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        isMenuPresented.toggle()
                    }
                } label: {
                    Image(systemName: "person")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(theme.primaryText.opacity(isMenuPresented ? 1 : 0.9))
                        .frame(width: 32, height: 32)
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(isMenuPresented ? theme.accentSuccess.opacity(0.95) : theme.accentSuccess.opacity(0.4))
                                .frame(width: 5, height: 5)
                                .offset(x: -1, y: -2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .relationships:
                RelationshipsView()
            }
        }
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Good morning, \(store.greetingName)")
                    .font(.system(size: 31, weight: .semibold, design: theme.displayDesign))
                    .foregroundStyle(theme.primaryText)

                Text(store.homeStatusLine)
                    .font(.system(.subheadline, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Communication Health")
                        .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                        .foregroundStyle(theme.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("82")
                            .font(.system(size: 28, weight: .semibold, design: theme.displayDesign))
                            .foregroundStyle(theme.primaryText)

                        Text("↑ 6 this month")
                            .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                            .foregroundStyle(theme.accentSuccess)
                    }
                }

                Spacer()

                Circle()
                    .stroke(theme.accentSuccess.opacity(0.28), lineWidth: 1.25)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle()
                            .fill(theme.accentSuccess.opacity(0.12))
                            .frame(width: 22, height: 22)
                    }
            }
        }
        .padding(.top, 6)
    }

    private var startListeningRow: some View {
        Button {
            selectedTab = .listen
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 34, height: 34)
                    .background(theme.accentSuccess.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Listening")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)

                    Text("Record a conversation, meeting, 1:1, date, or coaching session.")
                        .font(.system(.caption, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.accentSuccess.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var todaysDiscoveryCard: some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.accentSuccess.opacity(0.9), theme.accentCool.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 14) {
                Text("Today’s insight")
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .textCase(.uppercase)

                Text(store.todaysDiscovery.title)
                    .font(.system(size: 25, weight: .semibold, design: theme.displayDesign))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.todaysDiscovery.evidence)
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.accentSuccess)

                Button {
                    askQuerySeed = "Why does this happen?"
                    selectedTab = .ask
                } label: {
                    HStack(spacing: 8) {
                        Text("See why")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.accentSuccess.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: theme.accentSuccess.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private var patternsToWatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Patterns to watch")

            ForEach(store.homePatternAlerts) { alert in
                Button {
                    selectedTab = .patterns
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Text("⚠")
                            .font(.system(size: 15))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(alert.title)
                                .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                                .multilineTextAlignment(.leading)

                            Text("Show me")
                                .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                                .foregroundStyle(theme.accentStrong)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if alert.id != store.homePatternAlerts.last?.id {
                    Divider()
                        .overlay(theme.border.opacity(0.65))
                }
            }
        }
    }

    private var peopleStripSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Key relationships")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.peopleSnapshots) { person in
                        Button {
                            route = .relationships
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(theme.accentSuccess.opacity(0.1))
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            Text(initials(for: person.name))
                                                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                                                .foregroundStyle(theme.primaryText)
                                        }

                                    Spacer()
                                }

                                Text(person.name)
                                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                                    .foregroundStyle(theme.primaryText)

                                Text("\(person.direction) \(person.status)")
                                    .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                                    .foregroundStyle(person.direction == "↑" ? theme.accentSuccess : theme.accentStrong)
                            }
                            .frame(width: 108, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(theme.border.opacity(0.7), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var askAnythingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask Anything")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            Button {
                askQuerySeed = store.askSuggestions.first ?? ""
                selectedTab = .ask
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(theme.secondaryText)

                    Text("Ask about your communication…")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.askSuggestions.prefix(4), id: \.self) { suggestion in
                        Button {
                            askQuerySeed = suggestion
                            selectedTab = .ask
                        } label: {
                            Text(suggestion)
                                .font(.system(.caption, design: theme.bodyDesign).weight(.medium))
                                .foregroundStyle(theme.secondaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(theme.chipBackground.opacity(0.82), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.7), lineWidth: 1)
        )
    }

    private var recentTrendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Recent trends")

            VStack(alignment: .leading, spacing: 12) {
                ForEach(store.recentDiscoveries.prefix(3)) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(theme.accentSuccess.opacity(0.68))
                            .frame(width: 6, height: 6)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(item.context)
                                .font(.system(.caption, design: theme.bodyDesign))
                                .foregroundStyle(theme.secondaryText)
                        }

                        Spacer()
                    }

                    if item.id != store.recentDiscoveries.prefix(3).last?.id {
                        Divider()
                            .overlay(theme.border.opacity(0.65))
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: theme.displayDesign).weight(.semibold))
            .foregroundStyle(theme.primaryText)
    }

    private func initials(for name: String) -> String {
        let words = name.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters)
    }
}

private func selectionChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(selected ? Color(red: 0.16, green: 0.22, blue: 0.26) : Color.white.opacity(0.84))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background((selected ? Color.white.opacity(0.86) : Color.white.opacity(0.08)), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(selected ? 0 : 0.12), lineWidth: 1)
            )
    }
    .buttonStyle(.plain)
}

private func bulletRow(_ text: String, accent: Color = .orange) -> some View {
    HStack(alignment: .top, spacing: 12) {
        Circle()
            .fill(accent)
            .frame(width: 8, height: 8)
            .padding(.top, 7)

        Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.84))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DialogueMark: View {
    let theme: PresenceTheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.accentSuccess.opacity(0.28), lineWidth: 1.6)
                .frame(width: 24, height: 24)

            Circle()
                .stroke(theme.accentSuccess.opacity(0.18), lineWidth: 1.2)
                .frame(width: 16, height: 16)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.accentSuccess, theme.accentCool],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 8, height: 8)
                .offset(y: -3)
        }
        .frame(width: 28, height: 24)
    }
}

private struct HomeBackdrop: View {
    let theme: PresenceTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.985, green: 0.958, blue: 0.906),
                    Color(red: 0.972, green: 0.936, blue: 0.876)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(theme.accentSuccess.opacity(0.1))
                .frame(width: 320, height: 320)
                .blur(radius: 54)
                .offset(x: -150, y: -260)

            Circle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 180, y: -120)

            Circle()
                .fill(theme.accentCool.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 56)
                .offset(x: 120, y: 260)
        }
    }
}

private struct SlideOutMenu: View {
    let theme: PresenceTheme
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Presence")
                        .font(.system(.headline, design: theme.displayDesign).weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    Text("Explore")
                        .font(.system(.caption, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.55), in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                NavigationLink {
                    RelationshipsView()
                        .onAppear { isPresented = false }
                } label: {
                    menuRow("Relationships", systemImage: "person.2.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PatternsView()
                        .onAppear { isPresented = false }
                } label: {
                    menuRow("Patterns", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ReflectionsView()
                        .onAppear { isPresented = false }
                } label: {
                    menuRow("Reflections", systemImage: "rectangle.stack.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SettingsPrototypeView()
                        .onAppear { isPresented = false }
                } label: {
                    menuRow("Settings", systemImage: "gearshape.fill")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(width: 220, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.92), theme.backgroundTop.opacity(0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: theme.heroEnd.opacity(0.14), radius: 22, x: -8, y: 10)
    }

    private func menuRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.accentStrong)
                .frame(width: 24)

            Text(title)
                .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct RelationshipsView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var selectedKind: KeyRelationshipKind = .partner

    private var theme: PresenceTheme {
        themeStore.current
    }

    private var selectedProfile: KeyRelationshipProfile {
        store.keyRelationshipProfiles.first(where: { $0.kind == selectedKind }) ?? store.keyRelationshipProfiles[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                relationshipsHero

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.keyRelationshipProfiles) { profile in
                            selectionChip(profile.kind.title, selected: selectedKind == profile.kind) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    selectedKind = profile.kind
                                }
                            }
                        }
                    }
                }

                relationshipDetailCard(selectedProfile)
                relationshipSignalsCard(selectedProfile)
                relationshipRecentChangesCard(selectedProfile)
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Relationships")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var relationshipsHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key relationships")
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.accentSuccess)
                .textCase(.uppercase)
                .tracking(0.7)

            Text("You show up differently depending on who’s in front of you.")
                .font(.system(size: 28, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text("Presence can build a communication profile for the people and dynamics that matter most.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.top, 6)
    }

    private func relationshipDetailCard(_ profile: KeyRelationshipProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(profile.kind.title)
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.accentSuccess)
                .textCase(.uppercase)

            Text(profile.headline)
                .font(.system(size: 24, weight: .semibold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text(profile.summary)
                .font(.system(.body, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .presencePanel(theme: theme, prominence: .elevated)
    }

    private func relationshipSignalsCard(_ profile: KeyRelationshipProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What tends to happen")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            ForEach(profile.signals, id: \.self) { signal in
                bulletRow(signal)
            }
        }
        .padding(20)
        .presencePanel(theme: theme, prominence: .standard)
    }

    private func relationshipRecentChangesCard(_ profile: KeyRelationshipProfile) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent changes")
                    .font(.system(.headline, design: theme.bodyDesign))
                    .foregroundStyle(theme.primaryText)

            Text(recentChangeText(for: profile.kind))
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .presencePanel(theme: theme, prominence: .standard)
    }

    private func recentChangeText(for kind: KeyRelationshipKind) -> String {
        switch kind {
        case .partner:
            return "Your conversations here have become a little more productive lately, especially when you stay with the emotional layer before solving."
        case .boss:
            return "You’ve been more concise recently, but also slightly more deferential than your baseline."
        case .family:
            return "You’ve been more patient on the surface, though still slower to name the real issue directly."
        case .friend:
            return "You sound especially warm here, but you’ve also been avoiding disappointment more often in recent conversations."
        }
    }
}

private struct PatternsView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var filters = PatternDashboardFilters()
    @State private var selectedPointID: PatternChartPoint.ID?
    @State private var selectedInsight: String?
    @State private var historySearch = ""
    @State private var selectedConversation: PatternHistoryEntry?
    @State private var activePicker: PatternPicker?
    @State private var compareMode: PatternCompareMode = .baseline
    @State private var historySort: PatternHistorySort = .mostRecent

    private var theme: PresenceTheme {
        themeStore.current
    }

    private var dashboard: PatternDashboardData {
        store.patternsDashboard(for: filters)
    }

    private var visibleHistory: [PatternHistoryEntry] {
        let base = dashboard.history.filter { entry in
            historySearch.isEmpty || entry.title.localizedCaseInsensitiveContains(historySearch) || entry.summary.localizedCaseInsensitiveContains(historySearch)
        }

        let pointAdjusted: [PatternHistoryEntry]
        if let selectedPointID, let point = dashboard.chartPoints.first(where: { $0.id == selectedPointID }) {
            let slice = max(1, min(base.count, dashboard.chartPoints.firstIndex(where: { $0.id == point.id }).map { $0 + 1 } ?? base.count))
            pointAdjusted = Array(base.prefix(slice))
        } else {
            pointAdjusted = base
        }

        if selectedInsight != nil {
            return sortHistory(Array(pointAdjusted.prefix(2)))
        }

        return sortHistory(pointAdjusted)
    }

    private var hasActiveFilters: Bool {
        filters != PatternDashboardFilters()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                patternsHeader
                keyFindingCard
                summaryMetricsSection
                chartSection
                explanationSection
                heatmapSection
                patternInsightsSection
                conversationHistorySection
            }
            .padding(20)
            .padding(.top, 58)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            stickyFilterBar
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.985, green: 0.958, blue: 0.906).opacity(0.98),
                            Color(red: 0.985, green: 0.958, blue: 0.906).opacity(0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .navigationTitle("Patterns")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedConversation) { entry in
            PatternConversationDetailView(entry: entry)
        }
        .sheet(item: $activePicker) { picker in
            PatternFilterPickerSheet(picker: picker, filters: $filters, theme: theme)
                .presentationDetents([.medium, .large])
        }
    }

    private var patternsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patterns")
                .font(.system(size: 30, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text("Explore what changes across people, topics, and conversations.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.top, 6)
    }

    private var stickyFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                compactFilterChip(title: personChipTitle, picker: .person)
                compactFilterChip(title: typeChipTitle, picker: .type)
                compactFilterChip(title: topicChipTitle, picker: .topic)
                compactFilterChip(title: filters.time.label, picker: .time)
                compactFilterChip(title: filters.metric.label, picker: .metric)

                if hasActiveFilters {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            filters = PatternDashboardFilters()
                            selectedPointID = nil
                            selectedInsight = nil
                            historySearch = ""
                        }
                    } label: {
                        Text("Reset")
                            .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                            .foregroundStyle(theme.accentStrong)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.7), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var keyFindingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dashboard.keyFindingTitle)
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)

            Text(dashboard.keyFindingDetail)
                .font(.system(size: 24, weight: .semibold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(dashboard.keyFindingEvidence)
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)

            Button {
                selectedInsight = dashboard.insights.first
            } label: {
                HStack(spacing: 8) {
                    Text("See evidence")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                .foregroundStyle(theme.accentStrong)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.accentSuccess.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: theme.accentSuccess.opacity(0.07), radius: 16, x: 0, y: 10)
    }

    private var summaryMetricsSection: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(dashboard.summaries.prefix(4)) { summary in
                VStack(alignment: .leading, spacing: 10) {
                    Text(summary.title)
                        .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                        .foregroundStyle(theme.secondaryText)
                        .textCase(.uppercase)

                    HStack(alignment: .firstTextBaseline) {
                        Text(summary.value)
                            .font(.system(size: 22, weight: .semibold, design: theme.displayDesign))
                            .foregroundStyle(theme.primaryText)

                        Spacer(minLength: 0)
                    }

                    Text(summary.delta)
                        .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                        .foregroundStyle(summary.delta.contains("↓") ? theme.accentStrong : theme.accentSuccess)

                    Text(metricContextLine(for: summary.title))
                        .font(.system(.caption2, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.border.opacity(0.72), lineWidth: 1)
                )
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dashboard.chartTitle)
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)

                    Text(dashboard.chartSubtitle)
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()

                Menu {
                    ForEach(PatternCompareMode.allCases) { mode in
                        Button(mode.label) {
                            compareMode = mode
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(compareMode.label)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.72), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if let emptyState = dashboard.emptyState {
                Text(emptyState)
                    .font(.system(.subheadline, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.vertical, 10)
            } else {
                PatternChartView(
                    theme: theme,
                    points: dashboard.chartPoints,
                    selectedPointID: $selectedPointID
                )
                .frame(height: 188)

                HStack(alignment: .center) {
                    Text(chartContextLine)
                        .font(.system(.caption, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)

                    Spacer()

                    Button {
                        selectedInsight = dashboard.insights.first
                    } label: {
                        Text("Explain trend")
                            .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                            .foregroundStyle(theme.accentStrong)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.72), lineWidth: 1)
        )
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dashboard.explanationTitle)
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            ForEach(dashboard.explanationBullets, id: \.self) { item in
                bulletRow(item, accent: theme.accentWarm)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.72), lineWidth: 1)
        )
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Relationship comparison")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            Text("You communicate differently with different people.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)

            PatternHeatmapView(
                theme: theme,
                rows: store.heatmapRows(for: filters),
                columns: ["Listening", "Warmth", "Interrupt.", "Direct."]
            )
        }
        .padding(18)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.72), lineWidth: 1)
        )
    }

    private var patternInsightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pattern insights")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            if let emptyState = dashboard.emptyState {
                Text(emptyState)
                    .font(.system(.subheadline, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
            } else {
                ForEach(dashboard.insights, id: \.self) { insight in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedInsight = selectedInsight == insight ? nil : insight
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(theme.accentWarm)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)

                                Text(insight)
                                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                                    .foregroundStyle(theme.primaryText)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }

                            if selectedInsight == insight {
                                Text("Supporting conversations below are filtered to the most relevant recent matches.")
                                    .font(.system(.caption, design: theme.bodyDesign))
                                    .foregroundStyle(theme.secondaryText)
                                    .padding(.leading, 18)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.72), lineWidth: 1)
        )
    }

    private var conversationHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Conversation History")
                    .font(.system(.headline, design: theme.bodyDesign))
                    .foregroundStyle(theme.primaryText)

                Spacer()

                Menu {
                    ForEach(PatternHistorySort.allCases) { option in
                        Button(option.label) {
                            historySort = option
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(historySort.shortLabel)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.secondaryText)

                TextField("Search conversations", text: $historySearch)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: theme.bodyDesign))
                    .foregroundStyle(theme.primaryText)
            }
            .padding(14)
            .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if visibleHistory.isEmpty {
                Text("No matching conversations to show.")
                    .font(.system(.subheadline, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(visibleHistory) { entry in
                    Button {
                        selectedConversation = entry
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.title)
                                        .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                                        .foregroundStyle(theme.primaryText)

                                    Text(entry.meta)
                                        .font(.system(.caption, design: theme.bodyDesign))
                                        .foregroundStyle(theme.secondaryText)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(theme.secondaryText.opacity(0.7))
                                    .padding(.top, 4)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(entry.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                                            .foregroundStyle(theme.accentStrong)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.56), in: Capsule())
                                    }
                                }
                            }

                            Text(entry.signal)
                                .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                                .foregroundStyle(theme.accentSuccess)

                            Text(entry.summary)
                                .font(.system(.subheadline, design: theme.bodyDesign))
                                .foregroundStyle(theme.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(theme.border.opacity(0.72), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.72), lineWidth: 1)
        )
    }

    private func compactFilterChip(title: String, picker: PatternPicker) -> some View {
        Button {
            activePicker = picker
        } label: {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.78), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var personChipTitle: String {
        filters.person == .all ? "All People" : filters.person.label
    }

    private var typeChipTitle: String {
        filters.conversationType == .all ? "All Types" : filters.conversationType.label
    }

    private var topicChipTitle: String {
        filters.topic == .all ? "All Topics" : filters.topic.label
    }

    private var chartContextLine: String {
        "\(dashboard.chartSubtitle) • vs \(compareMode.label.lowercased())"
    }

    private func metricContextLine(for title: String) -> String {
        switch title.lowercased() {
        case "talk time":
            return "+8% vs usual"
        case "interruptions":
            return "Past \(filters.time.label.lowercased())"
        case "questions":
            return "+12 vs baseline"
        default:
            return "+14 vs baseline"
        }
    }

    private func sortHistory(_ history: [PatternHistoryEntry]) -> [PatternHistoryEntry] {
        switch historySort {
        case .mostRecent:
            return history
        case .highestConflict:
            return history.sorted { ($0.tags.contains("Conflict") ? 1 : 0) > ($1.tags.contains("Conflict") ? 1 : 0) }
        case .mostProductive:
            return history.sorted { ($0.signal.contains("Warmer") || $0.signal.contains("Listening")) && !($1.signal.contains("Warmer") || $1.signal.contains("Listening")) }
        case .biggestImprovement:
            return history.sorted { $0.signal.localizedCaseInsensitiveContains("up") && !$1.signal.localizedCaseInsensitiveContains("up") }
        case .mostSurprising:
            return history.sorted { $0.summary.count > $1.summary.count }
        }
    }
}

private enum PatternPicker: String, Identifiable {
    case person, type, topic, time, metric

    var id: String { rawValue }
}

private enum PatternCompareMode: CaseIterable, Identifiable {
    case baseline, lastMonth, person, topic, conversationType

    var id: String { label }

    var label: String {
        switch self {
        case .baseline: "Baseline"
        case .lastMonth: "Last month"
        case .person: "Person"
        case .topic: "Topic"
        case .conversationType: "Type"
        }
    }
}

private enum PatternHistorySort: CaseIterable, Identifiable {
    case mostRecent, highestConflict, mostProductive, biggestImprovement, mostSurprising

    var id: String { label }

    var label: String {
        switch self {
        case .mostRecent: "Most recent"
        case .highestConflict: "Highest conflict"
        case .mostProductive: "Most productive"
        case .biggestImprovement: "Biggest improvement"
        case .mostSurprising: "Most surprising"
        }
    }

    var shortLabel: String {
        switch self {
        case .mostRecent: "Recent"
        case .highestConflict: "Conflict"
        case .mostProductive: "Productive"
        case .biggestImprovement: "Improvement"
        case .mostSurprising: "Surprising"
        }
    }
}

private struct PatternChartView: View {
    let theme: PresenceTheme
    let points: [PatternChartPoint]
    @Binding var selectedPointID: PatternChartPoint.ID?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let step = points.count > 1 ? size.width / CGFloat(points.count - 1) : size.width
            let maxHeight = size.height - 34

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.32))

                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(height: 1)
                }

                if !points.isEmpty {
                    Path { path in
                        for (index, point) in points.enumerated() {
                            let x = CGFloat(index) * step
                            let y = maxHeight - CGFloat(point.value) * maxHeight + 12
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [theme.accentCool, theme.accentStrong],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )

                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                            let selected = point.id == selectedPointID

                            Button {
                                selectedPointID = selected ? nil : point.id
                            } label: {
                                VStack(spacing: 8) {
                                    Spacer()

                                    Circle()
                                        .fill(selected ? theme.accentStrong : Color.white.opacity(0.92))
                                        .frame(width: selected ? 14 : 10, height: selected ? 14 : 10)
                                        .overlay(
                                            Circle()
                                                .stroke(theme.heroStart.opacity(0.16), lineWidth: 3)
                                        )
                                        .offset(y: pointOffset(for: point, height: maxHeight))

                                    Text(point.label)
                                        .font(.system(.caption2, design: theme.bodyDesign).weight(.semibold))
                                        .foregroundStyle(theme.secondaryText)
                                }
                                .frame(width: index == points.count - 1 ? step : step, height: size.height, alignment: .bottom)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func pointOffset(for point: PatternChartPoint, height: CGFloat) -> CGFloat {
        let y = height - CGFloat(point.value) * height
        return -(height - y) + 10
    }
}

private struct PatternHeatmapView: View {
    let theme: PresenceTheme
    let rows: [PatternHeatmapRow]
    let columns: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("")
                    .frame(width: 76, alignment: .leading)

                ForEach(columns, id: \.self) { column in
                    Text(column)
                        .font(.system(.caption2, design: theme.bodyDesign).weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Text(row.label)
                        .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .frame(width: 76, alignment: .leading)

                    ForEach(Array(row.values.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.accentCool.opacity(0.18 + value * 0.35),
                                        theme.accentStrong.opacity(0.12 + value * 0.48)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 28)
                            .overlay(
                                Text("\(Int(value * 100))")
                                    .font(.system(.caption2, design: theme.bodyDesign).weight(.bold))
                                    .foregroundStyle(theme.primaryText.opacity(0.78))
                            )
                    }
                }
            }
        }
    }
}

private struct PatternFilterPickerSheet: View {
    let picker: PatternPicker
    @Binding var filters: PatternDashboardFilters
    let theme: PresenceTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch picker {
                    case .person:
                        optionList(PatternPersonFilter.allCases, selected: filters.person, label: \.label) { filters.person = $0 }
                    case .type:
                        optionList(PatternConversationFilter.allCases, selected: filters.conversationType, label: \.label) { filters.conversationType = $0 }
                    case .topic:
                        optionList(PatternTopicFilter.allCases, selected: filters.topic, label: \.label) { filters.topic = $0 }
                    case .time:
                        optionList(PatternTimeFilter.allCases, selected: filters.time, label: \.label) { filters.time = $0 }
                    case .metric:
                        optionList(PatternMetricFilter.allCases, selected: filters.metric, label: \.label) { filters.metric = $0 }
                    }
                }
                .padding(20)
            }
            .background(InsightBackdrop(theme: theme).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var title: String {
        switch picker {
        case .person: "People"
        case .type: "Conversation Type"
        case .topic: "Topic"
        case .time: "Time"
        case .metric: "Metric"
        }
    }

    private func optionList<Option: Hashable & Identifiable>(
        _ options: [Option],
        selected: Option,
        label: KeyPath<Option, String>,
        onSelect: @escaping (Option) -> Void
    ) -> some View {
        ForEach(options) { option in
            Button {
                onSelect(option)
                dismiss()
            } label: {
                HStack {
                    Text(option[keyPath: label])
                        .font(.system(.body, design: theme.bodyDesign).weight(.medium))
                        .foregroundStyle(theme.primaryText)

                    Spacer()

                    if option == selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.accentSuccess)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.border.opacity(0.8), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct PatternConversationDetailView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    let entry: PatternHistoryEntry

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.title)
                        .font(.system(size: 28, weight: .bold, design: theme.displayDesign))
                        .foregroundStyle(theme.primaryText)

                    Text(entry.meta)
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(22)
                .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(theme.border.opacity(0.72), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Key signal")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)

                    Text(entry.signal)
                        .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                        .foregroundStyle(theme.accentStrong)

                    Text(entry.summary)
                        .font(.system(.body, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(20)
                .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(theme.border.opacity(0.72), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Topics")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)

                    HStack(spacing: 8) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                                .foregroundStyle(theme.accentStrong)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.56), in: Capsule())
                        }
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(theme.border.opacity(0.72), lineWidth: 1)
                )
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct AskView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var themeStore: ThemeStore
    @Binding var querySeed: String
    @State private var query = ""

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                askHero
                askInputCard
                commonQuestionsCard
                sampleAnswerCard
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            adoptSeedIfNeeded()
        }
        .onChange(of: querySeed) { _, _ in
            adoptSeedIfNeeded()
        }
    }

    private var askHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask anything about how you show up.")
                .font(.system(size: 28, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text("Presence should eventually let you query your communication data in plain language instead of hunting through sections.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.top, 6)
    }

    private var askInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask a question")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            TextField("Who do I interrupt most?", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.body, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)
                .padding(16)
                .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if !query.isEmpty {
                Text("Running on your recent communication data")
                    .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.accentStrong)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.72), lineWidth: 1)
        )
    }

    private var commonQuestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try asking")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            ForEach(store.askSuggestions, id: \.self) { prompt in
                Button {
                    querySeed = prompt
                    adoptSeedIfNeeded()
                } label: {
                    Text(prompt)
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.72), lineWidth: 1)
        )
    }

    private var sampleAnswerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sample answer")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            Text(answerText(for: query))
                .font(.system(.body, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.72), lineWidth: 1)
        )
    }

    private func adoptSeedIfNeeded() {
        guard !querySeed.isEmpty else { return }
        query = querySeed
    }

    private func answerText(for query: String) -> String {
        let lower = query.lowercased()
        if lower.contains("partner") && lower.contains("tense") {
            return "Conversations with your partner tend to get tense when logistics turn into feeling unappreciated. You usually move into explanation quickly at that point, which seems to make the exchange feel sharper."
        }
        if lower.contains("better listener") {
            return "Compared with last month, you’re interrupting less and asking more follow-up questions in repair conversations. The improvement is real, but it’s not evenly distributed across every context yet."
        }
        if lower.contains("interrupt") {
            return "You interrupt your team most often in group settings where you already have a strong point of view. In 1:1s, you leave more space and ask more follow-up questions before responding."
        }
        if lower.contains("changed") || lower.contains("month") {
            return "This month, your tone has become a little more direct in money conversations, while your strongest improvement has been leaving more space before jumping in during emotionally loaded discussions."
        }
        return "Presence is starting to surface how context changes your communication. The strongest pattern right now is that you become more persuasive when you ground recommendations in one concrete example before making your point."
    }
}

private struct ReflectionsView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var themeStore: ThemeStore

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                overviewCard
                recentSessions
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Reflections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reflections")
                .font(.system(size: 28, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text("A calmer view of what tends to happen, what’s improving, and which conversations are shaping your communication over time.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)

            libraryInsight(
                title: "What tends to happen",
                text: store.recurringPatternSummary,
                accent: theme.accentWarm
            )

            libraryInsight(
                title: "What's improving",
                text: store.improvementSummary,
                accent: theme.accentSuccess
            )
        }
        .padding(.top, 6)
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent reflections")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            ForEach(store.recentSessions.prefix(6)) { session in
                NavigationLink {
                    ResultsView(session: session)
                } label: {
                    LibrarySessionCard(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func libraryInsight(title: String, text: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(accent)
                    .frame(width: 12, height: 12)
                Text(title)
                    .font(.system(.headline, design: theme.bodyDesign))
                    .foregroundStyle(theme.primaryText)
            }

            Text(text)
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .presencePanel(theme: theme, prominence: .standard, cornerRadius: 22)
    }
}

private struct TextConversationPrototypeView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var themeStore: ThemeStore

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                textHero
                uploadOptions
                samplePreview
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Text conversations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var textHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text conversations")
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.accentSuccess)
                .textCase(.uppercase)
                .tracking(0.7)

            Text("Presence can expand beyond spoken conversations and coach you through text threads too.")
                .font(.system(size: 26, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text("For now this is a prototype surface for screenshot upload, future imports, and text-specific coaching.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.top, 6)
    }

    private var uploadOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ways in")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            textOption(
                title: "Upload screenshots",
                detail: "Fastest v1 path: let users drop in a few screenshots from a text exchange."
            )

            textOption(
                title: "Import messages later",
                detail: "A future integration could bring in a thread directly once we decide where to start."
            )
        }
        .padding(20)
        .presencePanel(theme: theme, prominence: .elevated)
    }

    private var samplePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sample output")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            Text("A text version of Presence would still return the same core loop: what went well, where it got harder, how you showed up, and one thing to try next time.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)

            if let session = store.latestSession {
                NavigationLink {
                    ResultsView(session: session)
                } label: {
                    Label("Preview sample coaching", systemImage: "text.quote")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(theme.secondaryButtonBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .presencePanel(theme: theme, prominence: .standard)
    }

    private func textOption(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .presencePanel(theme: theme, prominence: .standard, cornerRadius: 22)
    }
}

private struct SettingsPrototypeView: View {
    @EnvironmentObject private var themeStore: ThemeStore

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: theme.displayDesign))
                        .foregroundStyle(theme.primaryText)

                    Text("A future settings area can hold privacy controls, transcript retention, notification preferences, and connected text sources.")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Likely sections")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)

                    settingsRow("Privacy and consent defaults")
                    settingsRow("Transcript storage and deletion")
                    settingsRow("Coaching tone and reminders")
                    settingsRow("Connected text sources")
                }
                .padding(20)
                .presencePanel(theme: theme, prominence: .standard)
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func settingsRow(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
            .foregroundStyle(theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .presencePanel(theme: theme, prominence: .standard, cornerRadius: 20)
    }
}

private struct LibrarySessionCard: View {
    @EnvironmentObject private var themeStore: ThemeStore

    let session: ConversationSession

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(session.setup.relationshipDisplayLabel ?? "Conversation", systemImage: session.setup.relationshipType?.symbolName ?? "circle.fill")
                    .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.accentStrong)

                Spacer()

                Text(relativeDateLabel(for: session.startedAt))
                    .font(.system(.caption, design: theme.bodyDesign))
                    .foregroundStyle(theme.mutedText)
            }

            Text(session.setup.conversationTypeDisplayLabel ?? "Conversation")
                .font(.system(.title3, design: theme.displayDesign).weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text(session.reflection.headline)
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .presencePanel(theme: theme, prominence: .standard, cornerRadius: 22)
    }

    private func relativeDateLabel(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

import SwiftUI
import AVFoundation

struct ToolsView: View {
    @Bindable var store: LumaStore
    @State private var minutes = 5
    @State private var animation = 5
    @State private var weatherLoading = false
    @AppStorage("luma.schedule.morning.hour") private var morningHour = 8
    @AppStorage("luma.schedule.morning.minute") private var morningMinute = 0
    @AppStorage("luma.schedule.morning.text") private var morningText = "BONJOUR"
    @AppStorage("luma.schedule.evening.hour") private var eveningHour = 20
    @AppStorage("luma.schedule.evening.minute") private var eveningMinute = 0
    @AppStorage("luma.schedule.evening.text") private var eveningText = "BONNE NUIT"

    var body: some View {
        EditorPage(title: "À afficher", subtitle: "Horloge, minuteurs et animations.") {
            Text("Chaque lancement remplace l’affichage précédent. Les commandes de pause agissent sur le minuteur ou chronomètre actif.")
                .font(.caption).foregroundStyle(Color("muted"))
            section("Visualiseur audio") {
                Text("Le micro de l’iPhone anime le panneau. Le son n’est ni enregistré ni envoyé ; seules les intensités sont transmises.")
                    .font(.caption).foregroundStyle(Color("muted"))
                PixelGrid(grid: (0..<8).map { row in
                    store.visualizerLevels.map { Int($0) > 7 - row }
                }, color: Color(store.draft.color.asset))
                    .aspectRatio(4, contentMode: .fit).padding(8).background(.black, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Niveaux sonores")
                if store.visualizerActive {
                    Button("Arrêter le micro") { store.stopVisualizer() }.buttonStyle(PrimaryButton())
                } else {
                    Button(store.visualizerStarting ? "Activation…" : "Activer le micro") {
                        Task { await store.startVisualizer() }
                    }.buttonStyle(PrimaryButton()).disabled(store.visualizerStarting)
                }
                Text("Laisse l’app ouverte et le panneau connecté.")
                    .font(.caption).foregroundStyle(Color("muted"))
            }
            section("Transcription en direct") {
                Text("Les paroles captées par le micro défilent sur le panneau. La reconnaissance reste sur l’iPhone.")
                    .font(.caption).foregroundStyle(Color("muted"))
                Text(store.transcription.text.isEmpty ? "Les paroles reconnues apparaîtront ici." : store.transcription.text)
                    .font(.body).frame(maxWidth: .infinity, alignment: .leading).padding(12).lumaCard(radius: 10)
                Text(store.transcription.status).font(.caption).foregroundStyle(Color("muted"))
                if store.transcription.isRunning {
                    Button("Arrêter la transcription") { store.stopTranscription() }.buttonStyle(PrimaryButton())
                } else {
                    Button("Démarrer la transcription") { Task { await store.startTranscription() } }
                        .buttonStyle(PrimaryButton()).disabled(!store.isReady)
                }
                Text("Attends « À l’écoute » pour parler et garde l’app ouverte. Si tu parles trop vite, l’affichage peut prendre du retard.")
                    .font(.caption).foregroundStyle(Color("muted"))
            }
            section("Compte-tours OBD") {
                OBDControlsView(store: store)
            }
            section("Horloge") {
                Text("Heure, date et jour alternent. L’heure est synchronisée à la connexion.")
                    .font(.caption).foregroundStyle(Color("muted"))
                Button("Afficher l’horloge") { store.sendMode(1) }.buttonStyle(PrimaryButton())
            }
            section("Chronomètre") {
                Button("Démarrer à zéro") { store.sendMode(2) }.buttonStyle(PrimaryButton())
                controls
            }
            section("Minuteur") {
                Stepper("Durée : \(minutes) min", value: $minutes, in: 1...99)
                Button("Lancer le minuteur") { store.sendMode(3, seconds: minutes * 60) }.buttonStyle(PrimaryButton())
                Text("La barre indique le temps écoulé ; le panneau clignote à la fin.")
                    .font(.caption).foregroundStyle(Color("muted"))
                controls
            }
            section("Pomodoro") {
                Text("25 min de concentration, puis 5 min de pause, en boucle.")
                    .font(.caption).foregroundStyle(Color("muted"))
                Button("Démarrer Pomodoro") { store.sendMode(4, seconds: 25 * 60) }.buttonStyle(PrimaryButton())
                controls
            }
            section("Animations") {
                Picker("Animation", selection: $animation) {
                    Text("Cœur").tag(5); Text("Étoiles").tag(6); Text("Pluie").tag(7)
                    Text("Flèche").tag(8); Text("Surprise").tag(9)
                }
                Button("Afficher l’animation") { store.sendMode(animation) }.buttonStyle(PrimaryButton())
            }
            section("Météo · Grenoble") {
                Text("Conditions actuelles chargées sur Internet, puis envoyées au panneau.")
                    .font(.caption).foregroundStyle(Color("muted"))
                Button(weatherLoading ? "Chargement…" : "Afficher la météo") {
                    weatherLoading = true
                    Task { await store.showGrenobleWeather(); weatherLoading = false }
                }.buttonStyle(PrimaryButton()).disabled(weatherLoading)
            }
            section("Messages programmés") {
                Text("Ils se déclenchent seulement pendant la connexion Bluetooth. Après redémarrage du panneau, programme-les à nouveau.")
                    .font(.caption).foregroundStyle(Color("muted"))
                schedule("Matin", hour: $morningHour, minute: $morningMinute, text: $morningText, index: 0)
                schedule("Soir", hour: $eveningHour, minute: $eveningMinute, text: $eveningText, index: 1)
                Text("Lettres sans accents, chiffres et espaces ; 16 caractères maximum. Vide le message pour le désactiver.")
                    .font(.caption).foregroundStyle(Color("muted"))
            }
        }
        .onDisappear { store.stopVisualizer(); store.stopOBD(); store.stopTranscription() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.didBecomeInactiveNotification)
            .receive(on: RunLoop.main)) { notification in
            if let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
               context.source == .app { return }
            store.stopVisualizer()
            store.stopTranscription()
        }
    }

    private var controls: some View {
        HStack {
            Button("Pause") { store.controlMode(0) }
            Spacer()
            Button("Reprendre") { store.controlMode(1) }
            Spacer()
            Button("Remise à zéro") { store.controlMode(2) }
        }.font(.footnote.bold()).frame(minHeight: 44)
    }

    private func schedule(_ title: String, hour: Binding<Int>, minute: Binding<Int>, text: Binding<String>, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.bold())
            VStack {
                Stepper("\(hour.wrappedValue) h", value: hour, in: 0...23)
                Stepper("\(minute.wrappedValue) min", value: minute, in: 0...59)
            }
            TextField("Message", text: text).textInputAutocapitalization(.characters).autocorrectionDisabled()
                .padding(10).lumaCard(radius: 10)
            Button("Programmer \(title.lowercased())") {
                store.scheduleMessage(index: index, hour: hour.wrappedValue, minute: minute.wrappedValue, text: text.wrappedValue)
            }.buttonStyle(QuietButton()).lumaCard(radius: 10)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).lumaCard()
    }
}


struct WeatherResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
        var message: String? {
            guard temperature_2m.isFinite, (-100...100).contains(temperature_2m) else { return nil }
            let condition: String
            switch weather_code {
            case 0: condition = "SOLEIL"
            case 1...3, 45, 48: condition = "NUAGE"
            case 51...67, 80...82, 95...99: condition = "PLUIE"
            case 71...77, 85...86: condition = "NEIGE"
            default: condition = "METEO"
            }
            return "\(condition) \(Int(temperature_2m.rounded()))C"
        }
    }
    let current: Current
}

extension LumaStore {
    func showGrenobleWeather() async {
        guard isReady else { storageError = "Connecte le panneau avant d’envoyer la météo."; return }
        stopVisualizer()
        stopOBD()
        stopTranscription()
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=45.1885&longitude=5.7245&current=temperature_2m,weather_code") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let current = try JSONDecoder().decode(WeatherResponse.self, from: data).current
            guard let message = current.message else { throw URLError(.cannotParseResponse) }
            guard isReady else { storageError = "La connexion au panneau a été perdue."; return }
            let previousMessage = draft.message
            let previousMode = draft.scrollMode
            draft.message = message
            draft.scrollMode = .appearance
            display()
            draft.message = previousMessage
            draft.scrollMode = previousMode
        } catch {
            storageError = "Météo indisponible. Vérifie la connexion Internet et réessaie."
        }
    }
}

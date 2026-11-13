import SwiftUI
import UniformTypeIdentifiers
// Giả sử bạn đã thêm ZIPFoundation qua Swift Package Manager
import ZIPFoundation

// Giả lập lớp cầu nối lõi trò chơi (bạn cần thay thế bằng lệnh gọi C/ObjC thực tế của dự án mình)
class GameBridge {
    static let shared = GameBridge()
    func launchGame(wasmPath: String, preset: String) -> Bool {
        // TẠI ĐÂY: Gọi giao diện C của dự án port của bạn, ví dụ:
        // start_gta_native([wasmPath UTF8String], [preset UTF8String]);
        print("Khởi chạy lõi trò chơi, preset: \(preset)")
        return true
    }
}

struct ContentView: View {
    @State private var gameFilesPath: URL?
    @State private var isProcessing = false
    @State private var showFilePicker = false
    @State private var graphicsPreset = "Balanced" // Ultra Performance, Battery, Balanced, Quality
    @State private var statusMessage = "Vui lòng nhập gói tệp trò chơi"
    
    let presets = ["Ultra Performance", "Battery", "Balanced", "Quality", "Ultra"]
    
    var body: some View {
        ZStack {
            // Phong cách nền tối
            LinearGradient(gradient: Gradient(colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.15)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo và tiêu đề
                VStack {
                    Text("GTA V")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom))
                    Text("iOS Native Port")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .tracking(4)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Trạng thái / Khu vực tệp
                VStack(spacing: 15) {
                    Image(systemName: gameFilesPath == nil ? "folder.badge.plus" : "checkmark.seal.fill")
                        .font(.system(size: 50))
                        .foregroundColor(gameFilesPath == nil ? .gray : .green)
                    
                    Text(statusMessage)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: { showFilePicker = true }) {
                        Text(gameFilesPath == nil ? "Chọn gói tệp trò chơi (.zip)" : "Thay thế tệp")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 40)
                
                // Cài đặt đồ họa
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cài đặt đồ họa")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Picker("Preset", selection: $graphicsPreset) {
                        ForEach(presets, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .colorMultiply(.blue)
                }
                .padding(.horizontal, 20)
                .opacity(gameFilesPath == nil ? 0.5 : 1.0)
                .disabled(gameFilesPath == nil)
                
                Spacer()
                
                // Nút khởi chạy
                Button(action: startGame) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Bắt đầu trò chơi")
                    }
                    .font(.title3.bold())
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(gameFilesPath != nil ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(gameFilesPath == nil || isProcessing)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.zip], allowsMultipleSelection: false) { result in
            handleFileImport(result: result)
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            // Bắt đầu sao chép và giải nén
            processGameFile(sourceURL: selectedURL)
        case .failure(let error):
            statusMessage = "Lỗi chọn tệp: \(error.localizedDescription)"
        }
    }
    
    private func processGameFile(sourceURL: URL) {
        isProcessing = true
        statusMessage = "Đang sao chép tệp..."
        
        // Đảm bảo quyền truy cập tệp (quan trọng cho iOS)
        guard sourceURL.startAccessingSecurityScopedResource() else {
            statusMessage = "Không thể truy cập tệp"
            isProcessing = false
            return
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        let destinationDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destZipURL = destinationDir.appendingPathComponent("game.zip")
        let extractDir = destinationDir.appendingPathComponent("GameData")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 1. Sao chép zip vào thư mục sandbox
                if FileManager.default.fileExists(atPath: destZipURL.path) {
                    try FileManager.default.removeItem(at: destZipURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destZipURL)
                
                // 2. Giải nén
                DispatchQueue.main.async { statusMessage = "Đang giải nén tệp trò chơi..." }
                
                if FileManager.default.fileExists(atPath: extractDir.path) {
                    try FileManager.default.removeItem(at: extractDir)
                }
                try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
                
                // Sử dụng ZIPFoundation để giải nén
                try FileManager.default.unzipItem(at: destZipURL, to: extractDir)
                
                // 3. Xác minh game.wasm tồn tại
                let wasmURL = extractDir.appendingPathComponent("game.wasm")
                if FileManager.default.fileExists(atPath: wasmURL.path) {
                    DispatchQueue.main.async {
                        self.gameFilesPath = extractDir
                        self.statusMessage = "Sẵn sàng khởi chạy"
                        self.isProcessing = false
                    }
                } else {
                    // Đôi khi game.wasm nằm trong thư mục con
                    throw NSError(domain: "GameError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy game.wasm trong gói nén"])
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Lỗi xử lý: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func startGame() {
        guard let path = gameFilesPath else { return }
        isProcessing = true
        statusMessage = "Đang khởi động lõi trò chơi..."
        
        // TẠI ĐÂY: Gọi lõi trò chơi của bạn
        // Lưu ý: Các dự án port như vậy thường yêu cầu tắt UI hiện tại và chuyển sang view Metal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let success = GameBridge.shared.launchGame(wasmPath: path.appendingPathComponent("game.wasm").path, preset: self.graphicsPreset)
            if !success {
                self.statusMessage = "Khởi chạy thất bại, vui lòng kiểm tra nhật ký"
                self.isProcessing = false
            }
            // Nếu thành công, thường không cần cập nhật UI nữa vì trò chơi đã chiếm toàn màn hình
        }
    }
}

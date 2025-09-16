//
//  CreateSpaceView.swift
//  Spaces
//
//  Created by Stefan Blos on 16.02.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//
import PhotosUI
import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import CoreLocation

struct CreateSpaceView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var spacesViewModel: SpacesViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var happeningNow = true
    @State private var price: Double = 0.0
    @State private var isPriceEnabled = false
    @State private var isEditingPrice = false
    @State private var priceString = ""
    @State private var showPriceHint = false
    
    // Video Recording States
    @State private var isRecordingEnabled = false
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var showVideoPreview = false
    @State private var recordedVideoURL: URL?
    @State private var showVideoRecorder = false
 //   @StateObject private var locationManager = LocationManager.shared
    @State private var showLocationPermissionAlert = false

    // UI States
    @State private var selectedTab = 0
    @State private var showAdvancedOptions = false
    @State private var spaceType: SpaceType = .standard
    // Add this with other @StateObject declarations

    // Replace video-related state with photo state
    @State private var capturedImage: UIImage?
    @State private var showPhotoRecorder = false
    
    // Add LivePhoto model
    @State private var capturedLivePhoto: LivePhoto?
    
    // Add location-related states
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var latitudeBand: Int = 0
    
    // Add this property to the view
    private let defaultTestLocation = CLLocationCoordinate2D(
        latitude: 40.7128,  // New York City coordinates
        longitude: -74.0060
    )
    
    // Add this near the top of CreateSpaceView struct with other @State variables
    @State private var simulatedLocation: CLLocationCoordinate2D? = CLLocationCoordinate2D(
        latitude: 40.7128,  // New York City coordinates
        longitude: -74.0060
    )
    
    enum SpaceType: String, CaseIterable {
        case standard = "Standard"
        case premium = "Premium"
        case exclusive = "Exclusive"
        
        var icon: String {
            switch self {
            case .standard: return "star.fill"
            case .premium: return "crown.fill"
            case .exclusive: return "diamond.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .standard: return .blue
            case .premium: return .purple
            case .exclusive: return .orange
            }
        }
    }
    
    var necessaryInfoAvailable: Bool {
        return !title.isEmpty && !description.isEmpty && (isPriceEnabled ? price > 0 : true)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    spaceTypeSelection
                    mainForm
                    createButton
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create Space")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    dismissButton
                }
            }
           /* .sheet(isPresented: $showPhotoRecorder) {
                PhotoRecorderView(capturedLivePhoto: $capturedLivePhoto)
            }*/
            .onAppear {
                checkLocationPermission()
            }
            .alert("Location Access Required", isPresented: $showLocationPermissionAlert) {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Location access is required to create a space. Please enable location access in Settings.")
            }
        }
    }
    
    // MARK: - View Components
    private var spaceTypeSelection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(SpaceType.allCases, id: \.self) { type in
                    SpaceTypeCard(
                        type: type,
                        isSelected: spaceType == type,
                        action: { spaceType = type }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var mainForm: some View {
        VStack(spacing: 25) {
            basicInfoSection
            locationSection
            scheduleSection
            previewSection
            pricingSection
        }
        .padding()
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Space Details")
                .font(.title2)
                .bold()
            
            CustomTextField(
                text: $title,
                placeholder: "Space Title",
                icon: "textformat"
            )
            
            CustomTextField(
                text: $description,
                placeholder: "Space Description",
                icon: "text.justify",
                isMultiline: true
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Location")
                .font(.title2)
                .bold()
            
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                
                #if targetEnvironment(simulator)
                // Show default location for simulator
                VStack(alignment: .leading) {
                    Text("Test Location (NYC)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(String(format: "%.4f, %.4f",
                        defaultTestLocation.latitude,
                        defaultTestLocation.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                #else
                // Real device - show actual location
               /* if let location = locationManager.currentLocation?.coordinate {
                    VStack(alignment: .leading) {
                        Text("Current Location")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Fetching location...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }*/
                #endif
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Schedule")
                .font(.title2)
                .bold()
            
            CustomToggle(
                isOn: $happeningNow,
                title: "Start Now",
                icon: "bolt.fill"
            )
            
            if !happeningNow {
                CustomDatePicker(
                    date: $date,
                    icon: "calendar"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Space Preview")
                .font(.title2)
                .bold()
            
            PhotoRecordingCard(
                capturedLivePhoto: $capturedLivePhoto,
                showPhotoRecorder: $showPhotoRecorder
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        /*.sheet(isPresented: $showPhotoRecorder) {
            PhotoRecorderView(capturedLivePhoto: $capturedLivePhoto)
        }*/
    }
    
    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pricing")
                .font(.title2)
                .bold()
            
            CustomToggle(
                isOn: $isPriceEnabled,
                title: "Make this a paid space",
                icon: "dollarsign.circle.fill"
            )
            
            if isPriceEnabled {
                PriceInputCard(
                    price: $price,
                    priceString: $priceString,
                    isEditingPrice: $isEditingPrice,
                    showPriceHint: $showPriceHint
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var createButton: some View {
        Button {
            print("🔍 Create button tapped")
            
            #if targetEnvironment(simulator)
            let location = simulatedLocation ?? CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
            let latitudeBand = calculateLatitudeBand(latitude: location.latitude)
            #else
            let location = simulatedLocation ?? CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
            let latitudeBand = calculateLatitudeBand(latitude: location.latitude)
            #endif
            
            if let livePhoto = capturedLivePhoto {
                print("📸 Found Live Photo to save")
                if let imageURL = saveImageToFileSystem(image: livePhoto.image) {
                    print("✅ Saved Live Photo still image to: \(imageURL)")
                    spacesViewModel.createChannelForSpace(
                        title: title,
                        description: description,
                        date: date,
                        price: isPriceEnabled ? price : 0,
                        previewImageURL: imageURL,
                        location: location,
                        latitudeBand: latitudeBand
                    )
                }
            } else {
                print("⚠️ No Live Photo captured, creating space without image")
                spacesViewModel.createChannelForSpace(
                    title: title,
                    description: description,
                    date: date,
                    price: isPriceEnabled ? price : 0,
                    location: location,
                    latitudeBand: latitudeBand
                )
            }
            dismiss()
        } label: {
            HStack {
                Image(systemName: happeningNow ? "play.fill" : "calendar")
                Text(happeningNow ? "Start Space" : "Schedule Space")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        #if targetEnvironment(simulator)
        .disabled(!necessaryInfoAvailable)  // Only check title and description in simulator
        #else
        .disabled(!necessaryInfoAvailable)
        #endif
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundStyle(LinearGradient.spaceish)
        }
    }
    
    // Update saveImageToFileSystem to handle compression better
    private func saveImageToFileSystem(image: UIImage) -> URL? {
        print("📝 Starting image save to file system")
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Use higher quality compression for Live Photos
        if let imageData = image.jpegData(compressionQuality: 0.9) {
            do {
                try imageData.write(to: fileURL)
                print("✅ Successfully saved image to: \(fileURL)")
                return fileURL
            } catch {
                print("❌ Failed to write image data: \(error)")
                return nil
            }
        } else {
            print("❌ Failed to create JPEG data")
            return nil
        }
    }
    
    private func calculateLatitudeBand(latitude: Double) -> Int {
        return Int(floor((latitude + 90) / 4))  // Latitude range is between -90 to +90
    }


    
    private func checkLocationPermission() {
    /*    switch locationManager.authorizationStatus {
        case .notDetermined:
            // First time asking for permission
            print("📍 Requesting location permission...")
            locationManager.requestLocationPermission()
            
        case .restricted, .denied:
            // User previously denied or restricted access
            print("❌ Location access denied or restricted")
            showLocationPermissionAlert = true
            
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission already granted
            print("✅ Location access granted")
            break
            
        @unknown default:
            break
        }*/
    }
}

// MARK: - Supporting Views
struct SpaceTypeCard: View {
    let type: CreateSpaceView.SpaceType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .white : type.color)
                
                Text(type.rawValue)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 100, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? type.color : Color(.systemBackground))
                    .shadow(color: isSelected ? type.color.opacity(0.5) : .black.opacity(0.1),
                           radius: 10, x: 0, y: 5)
            )
        }
    }
}

struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var isMultiline: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            
            if isMultiline {
                TextEditor(text: $text)
                    .frame(height: 100)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct CustomToggle: View {
    @Binding var isOn: Bool
    let title: String
    let icon: String
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
        }
        .tint(.blue)
    }
}

struct CustomDatePicker: View {
    @Binding var date: Date
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            
            DatePicker("Schedule for:", selection: $date, in: Date()...,
                      displayedComponents: [.date, .hourAndMinute])
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct PriceInputCard: View {
    @Binding var price: Double
    @Binding var priceString: String
    @Binding var isEditingPrice: Bool
    @Binding var showPriceHint: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(alignment: .center, spacing: 2) {
                Text("$")
                    .foregroundColor(.green)
                    .font(.system(size: 30, weight: .bold))
                    .opacity(isEditingPrice ? 0.8 : 1.0)
                
                TextField("0.00", text: $priceString)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.leading)
                    .onChange(of: priceString) { newValue in
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if filtered != newValue {
                            priceString = filtered
                        }
                        
                        if let newPrice = Double(filtered) {
                            price = min(newPrice, 999.99)
                            if price != newPrice {
                                priceString = String(format: "%.2f", price)
                            }
                        } else {
                            price = 0.0
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isEditingPrice = true
                            showPriceHint = true
                        }
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.green.opacity(isEditingPrice ? 0.5 : 0.2), lineWidth: isEditingPrice ? 2 : 1)
                    .background(Color.green.opacity(0.05))
            )
            
            if showPriceHint {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💰 You will receive 80% of the payment")
                        .foregroundColor(.secondary)
                    Text("🎯 Recommended: $5 - $20")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if price > 0 {
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("You'll receive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", price * 0.8))")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading) {
                        Text("Platform fee")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", price * 0.2))")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// Add LivePhoto model if not already defined
struct LivePhoto {
    let image: UIImage
    let livePhoto: PHLivePhoto
}

// Update PhotoRecordingCard to use PHLivePhotoView
struct PhotoRecordingCard: View {
    @Binding var capturedLivePhoto: LivePhoto?
    @Binding var showPhotoRecorder: Bool
    @State private var isShowingFullScreen = false
    
    var body: some View {
        VStack(spacing: 15) {
            if let livePhoto = capturedLivePhoto {
                // Preview with live photo
                ZStack {
                    LivePhotoView(livePhoto: livePhoto.livePhoto)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Live photo indicator and controls
                    VStack {
                        HStack {
                            // Native Live Photo badge
                            LivePhotoBadge()
                                .padding(8)
                            
                            Spacer()
                            
                            Button {
                                capturedLivePhoto = nil
                                showPhotoRecorder = true
                            } label: {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(8)
                        
                        Spacer()
                    }
                }
                .onTapGesture {
                    isShowingFullScreen = true
                }
              /*  .fullScreenCover(isPresented: $isShowingFullScreen) {
                    LivePhotoPreviewFullScreen(
                        livePhoto: livePhoto,
                        isPresented: $isShowingFullScreen
                    ) {
                        capturedLivePhoto = nil
                        showPhotoRecorder = true
                    }
                }*/
                
            } else {
                // Take photo button
                Button {
                    showPhotoRecorder = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                        Text("Take Live Photo")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// Add LivePhotoView wrapper for PHLivePhotoView
struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    
    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        return view
    }
    
    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
    }
}

// Add LivePhotoBadge component
struct LivePhotoBadge: View {
    var body: some View {
        Image(uiImage: PHLivePhotoView.livePhotoBadgeImage(options: .overContent))
            .foregroundColor(.white)
    }
}
/*
// Update LivePhotoPreviewFullScreen
struct LivePhotoPreviewFullScreen: View {
    let livePhoto: LivePhoto
    @Binding var isPresented: Bool
    let retakeAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            LivePhotoView(livePhoto: livePhoto.livePhoto)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Overlay controls
            VStack {
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    LivePhotoBadge()
                        .padding(8)
                    
                    Button {
                        isPresented = false
                        retakeAction()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera")
                            Text("Retake")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .statusBar(hidden: true)
    }
}

// Update PhotoRecorderView Coordinato
    struct PhotoRecorderView: UIViewControllerRepresentable {
        @Binding var capturedLivePhoto: LivePhoto?
        @Environment(\.dismiss) var dismiss
        
        func makeUIViewController(context: Context) -> CreatePostVC {
            let vc = CreatePostVC()
            vc.delegate = context.coordinator
            return vc
        }
        
        func updateUIViewController(_ uiViewController: CreatePostVC, context: Context) {}
        
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CreatePostVCDelegate {
        let parent: PhotoRecorderView
        
        init(_ parent: PhotoRecorderView) {
            self.parent = parent
        }
        
        func didCaptureLivePhoto(_ livePhoto: PHLivePhoto, stillImage: UIImage) {
            DispatchQueue.main.async {
                self.parent.capturedLivePhoto = LivePhoto(image: stillImage, livePhoto: livePhoto)
                self.parent.dismiss()
            }
        }
        
        func didCapturePhoto(_ image: UIImage) {
            DispatchQueue.main.async {
                self.parent.dismiss()
            }
        }
        
        func didCancelPhotoCapture() {
            parent.dismiss()
        }
    }
}*/

struct CreateSpaceView_Previews: PreviewProvider {
    static var previews: some View {
        CreateSpaceView(spacesViewModel: .preview)
    }
}

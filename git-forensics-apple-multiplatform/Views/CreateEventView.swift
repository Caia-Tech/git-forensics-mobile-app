//
//  CreateEventView.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct CreateEventView: View {
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedType = EventType.general
    @State private var title = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Photo attachments
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var attachments: [EventAttachment] = []
    @State private var attachmentPreviews: [UUID: PlatformImage] = [:]
    @State private var isProcessingAttachments = false
    
    // File attachments
    @State private var showingDocumentPicker = false
    
    // Location
    @State private var includeLocation = false
    @State private var eventLocation: EventLocation?
    @State private var isGettingLocation = false
    @State private var showingLocationSettings = false
    
    private let attachmentManager = AttachmentManager.shared
    private let locationManager = LocationManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section("What happened?") {
                    // Event type picker
                    Picker("Type", selection: $selectedType) {
                        ForEach(EventType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    // Title field
                    TextField("Title", text: $title, prompt: Text("Brief description"))
                        .textFieldStyle(.roundedBorder)
                    
                    // Notes field
                    VStack(alignment: .leading) {
                        Text("Details")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                
                Section {
                    // Photo attachments
                    if !attachments.isEmpty {
                        attachmentPreviewsView
                    }
                    
                    // Add attachment options
                    attachmentOptionsView
                    
                    // Location
                    locationToggleView
                } header: {
                    Text("Additional Evidence")
                } footer: {
                    if !attachments.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(attachments.count) file(s) attached")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("Each file is cryptographically hashed for integrity verification")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if isProcessingAttachments {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing attachments...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Create Event")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEvent()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .keyboardShortcut(.defaultAction)
                }
                #endif
            }
            .disabled(isSaving || isProcessingAttachments)
            .sheet(isPresented: $showingLocationSettings) {
                LocationSettingsView()
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Saving securely...")
                                .padding()
                                .background(platformBackgroundColor)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func processSelectedImages() async {
        await MainActor.run {
            isProcessingAttachments = true
        }
        
        for item in selectedImages {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = PlatformImage(data: data) {
                    let attachment = try await attachmentManager.processImageAttachment(image)
                    
                    await MainActor.run {
                        attachments.append(attachment)
                        attachmentPreviews[attachment.id] = image
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to process image: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
        
        await MainActor.run {
            selectedImages.removeAll()
            isProcessingAttachments = false
        }
    }
    
    private func processSelectedFiles(_ result: Result<[URL], Error>) async {
        await MainActor.run {
            isProcessingAttachments = true
        }
        
        switch result {
        case .success(let urls):
            for url in urls {
                do {
                    let attachment = try await attachmentManager.processFileAttachment(from: url)
                    await MainActor.run {
                        attachments.append(attachment)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to process file \(url.lastPathComponent): \(error.localizedDescription)"
                        showingError = true
                    }
                }
            }
        case .failure(let error):
            await MainActor.run {
                errorMessage = "Failed to select files: \(error.localizedDescription)"
                showingError = true
            }
        }
        
        await MainActor.run {
            isProcessingAttachments = false
        }
    }
    
    private func removeAttachment(_ attachment: EventAttachment) {
        attachments.removeAll { $0.id == attachment.id }
        attachmentPreviews.removeValue(forKey: attachment.id)
    }
    
    private func getFileIcon(for mimeType: String) -> String {
        switch mimeType {
        case let type where type.hasPrefix("image/"): return "photo"
        case let type where type.hasPrefix("video/"): return "video"
        case let type where type.hasPrefix("audio/"): return "music.note"
        case "application/pdf": return "doc.richtext"
        case let type where type.contains("text"): return "doc.text"
        case let type where type.contains("spreadsheet"), let type where type.contains("excel"): return "tablecells"
        case let type where type.contains("presentation"), let type where type.contains("powerpoint"): return "rectangle.on.rectangle"
        case let type where type.contains("archive"), let type where type.contains("zip"): return "archivebox"
        default: return "doc"
        }
    }
    
    private func getCurrentLocation() {
        isGettingLocation = true
        
        Task {
            do {
                let location = try await locationManager.getCurrentLocation()
                await MainActor.run {
                    eventLocation = location
                    isGettingLocation = false
                }
            } catch {
                await MainActor.run {
                    includeLocation = false
                    eventLocation = nil
                    isGettingLocation = false
                    errorMessage = "Failed to get location: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var attachmentPreviewsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments) { attachment in
                    attachmentPreviewCard(for: attachment)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func attachmentPreviewCard(for attachment: EventAttachment) -> some View {
        VStack(spacing: 2) {
            if let preview = attachmentPreviews[attachment.id] {
                attachmentImageView(preview)
            } else {
                attachmentPlaceholderView(for: attachment)
            }
            
            Text(attachment.filename)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 60)
        }
        .overlay(alignment: .topTrailing) {
            removeAttachmentButton(attachment)
        }
    }
    
    private func attachmentImageView(_ preview: PlatformImage) -> some View {
        #if os(iOS)
        Image(uiImage: preview)
            .resizable()
            .scaledToFill()
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        #else
        Image(nsImage: preview)
            .resizable()
            .scaledToFill()
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        #endif
    }
    
    private func attachmentPlaceholderView(for attachment: EventAttachment) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: getFileIcon(for: attachment.mimeType))
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
    }
    
    private func removeAttachmentButton(_ attachment: EventAttachment) -> some View {
        Button(action: { removeAttachment(attachment) }) {
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.white)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
        }
        .offset(x: 8, y: -8)
    }
    
    private var attachmentOptionsView: some View {
        VStack(spacing: 8) {
            photoOptionsRow
            fileOptionsRow
        }
    }
    
    private var photoOptionsRow: some View {
        HStack {
            PhotosPicker(selection: $selectedImages,
                       maxSelectionCount: 5,
                       matching: .images) {
                Label("Choose Photos", systemImage: "photo")
            }
            .onChange(of: selectedImages) { _ in
                Task {
                    await processSelectedImages()
                }
            }
            
            Spacer()
            
            Button(action: { showingCamera = true }) {
                Label("Take Photo", systemImage: "camera")
            }
        }
    }
    
    private var fileOptionsRow: some View {
        HStack {
            Button(action: { showingDocumentPicker = true }) {
                Label("Add Files", systemImage: "doc")
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [
                    .pdf, .plainText, .rtf, .rtfd,
                    .spreadsheet, .presentation,
                    .archive, .data
                ],
                allowsMultipleSelection: true
            ) { result in
                Task {
                    await processSelectedFiles(result)
                }
            }
            
            Spacer()
        }
    }
    
    private var locationToggleView: some View {
        Group {
            if locationManager.locationEnabled && locationManager.isLocationAvailable {
                locationEnabledToggle
            } else {
                locationDisabledButton
            }
        }
    }
    
    private var locationEnabledToggle: some View {
        HStack {
            Toggle(isOn: $includeLocation) {
                locationToggleContent
            }
            .onChange(of: includeLocation) { newValue in
                if newValue {
                    getCurrentLocation()
                } else {
                    eventLocation = nil
                }
            }
        }
    }
    
    private var locationToggleContent: some View {
        HStack {
            Image(systemName: "location")
                .foregroundColor(includeLocation ? .blue : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Include Location")
                    .font(.body)
                locationStatusText
            }
        }
    }
    
    private var locationStatusText: some View {
        Group {
            if let location = eventLocation {
                Text("±\(Int(location.accuracyMeters))m accuracy")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if includeLocation {
                Text("Getting location...")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("Add GPS coordinates to this event")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var locationDisabledButton: some View {
        Button(action: { showingLocationSettings = true }) {
            HStack {
                Image(systemName: "location.slash")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Location Services")
                        .font(.body)
                        .foregroundColor(.primary)
                    Text("Add GPS coordinates to events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var platformBackgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(.controlBackgroundColor)
        #endif
    }
    
    // MARK: - Methods
    
    private func saveEvent() {
        isSaving = true
        
        Task {
            do {
                _ = try await eventManager.createEvent(
                    type: selectedType,
                    title: title,
                    notes: notes,
                    attachments: attachments,
                    location: includeLocation ? eventLocation : nil
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    CreateEventView()
        .environmentObject(EventManager.shared)
}
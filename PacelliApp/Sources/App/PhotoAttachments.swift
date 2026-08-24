import PacelliKit
import PhotosUI
import SwiftUI
import UIKit

/// The photos on one item, and the one control that adds more.
///
/// Nothing here asks a question at capture. No caption sheet, no category
/// picker, no confirmation — the thumbnail appears, the upload happens behind
/// it, and anything that needs correcting is corrected later from the photo
/// itself. `PhotosPicker` is deliberate too: it reads a chosen photo without
/// any photo-library permission prompt at all, so most people attach their
/// first picture without iOS asking them anything.
struct PhotoStrip: View {
    let subject: Photo.Subject
    let subjectId: String
    let householdId: String

    @State private var photos: [Photo] = []
    @State private var picked: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showChooser = false
    @State private var showLibrary = false
    @State private var busy = false
    @State private var viewing: Photo?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photos) { photo in
                        Button { viewing = photo } label: {
                            PhotoThumbnail(photo: photo)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("photo_thumb")
                    }

                    if busy {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                            .frame(width: 72, height: 72)
                            .overlay { ProgressView() }
                    }

                    // A plain button and a dialog, NOT a Menu with a
                    // PhotosPicker inside it. Nesting the picker in a Menu
                    // presents it and then leaves the menu behind: the sheet
                    // dismisses onto a still-open menu and the selection never
                    // reaches the binding.
                    Button {
                        showChooser = true
                    } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .frame(width: 72, height: 72)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .accessibilityIdentifier("photo_add")
                }
                .padding(.vertical, 2)
            }
        }
        // A live subscription, not a read. `.task(id:)` restarts it if the
        // strip is recycled onto a different item, and cancels it — which
        // removes the Firestore listener — when the view goes away.
        .task(id: subjectId) { await observe() }
        .confirmationDialog("Add a photo", isPresented: $showChooser, titleVisibility: .hidden) {
            Button("Take a photo") { showCamera = true }
            Button("Choose from library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        // No permission prompt: PhotosPicker reads the chosen image out of
        // process, so iOS never asks for library access.
        .photosPicker(
            isPresented: $showLibrary, selection: $picked,
            maxSelectionCount: 5, matching: .images)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task { await attachPicked(items) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture { data in
                showCamera = false
                guard let data else { return }
                Task { await attach(data) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $viewing) { photo in
            PhotoViewer(photo: photo, householdId: householdId) {
                Task {
                    try? await PhotoService.delete(photoId: photo.id, householdId: householdId)
                    viewing = nil
                }
            }
        }
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
    }

    private func observe() async {
        let stream = await PhotosRepository.observe(
            subjectId: subjectId, householdId: householdId)
        for await latest in stream {
            photos = latest
        }
    }

    private func attachPicked(_ items: [PhotosPickerItem]) async {
        picked = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            await attach(data)
        }
    }

    private func attach(_ data: Data) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await PhotoService.attach(
                imageData: data, to: subject, subjectId: subjectId,
                householdId: householdId)
            // No reload: Firestore's latency compensation fires the listener
            // on the local write before the round trip, so the thumbnail is
            // on screen sooner than a re-read would have put it there.
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Couldn't add that photo.")
        }
    }
}

/// A thumbnail straight out of the Firestore document — no network at all.
struct PhotoThumbnail: View {
    let photo: Photo
    var size: CGFloat = 72

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = photo.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            }

            if let label = stateLabel {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(4)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Sentences, not errors. Nothing here has lost the picture.
    private var stateLabel: String? {
        switch photo.uploadState {
        case .ready: return nil
        case .pending: return String(localized: "arriving")
        case .stranded: return String(localized: "on one phone")
        }
    }
}

/// Full screen, with the full-size image fetched and decrypted on demand.
struct PhotoViewer: View {
    let photo: Photo
    let householdId: String
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var loading = true
    @State private var failed: String?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if let data = photo.thumbnail, let thumb = UIImage(data: data) {
                    // The thumbnail is always there, so even a photo whose full
                    // size never arrived shows you the picture.
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .blur(radius: loading ? 6 : 0)
                        .overlay { if loading { ProgressView().tint(.white) } }
                }
                if let failed {
                    Text(failed)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 60)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityIdentifier("photo_delete")
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Delete this photo?", isPresented: $confirmingDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: onDelete)
            } message: {
                Text("It will be removed for everyone in the household.")
            }
        }
        .task { await load() }
    }

    private func load() async {
        defer { loading = false }
        switch photo.uploadState {
        case .stranded:
            failed = String(localized:
                "The full size never finished uploading from the phone that took it.")
            return
        case .pending:
            failed = String(localized: "The full size is still on its way.")
        case .ready:
            break
        }
        do {
            let data = try await PhotoService.fullImage(
                photoId: photo.id, householdId: householdId)
            image = UIImage(data: data)
            failed = nil
        } catch {
            if photo.uploadState == .ready {
                failed = String(localized: "Couldn't load the full size just now.")
            }
        }
    }
}

/// The camera. SwiftUI has no native capture view, so this is the UIKit one.
struct CameraCapture: UIViewControllerRepresentable {
    let onFinish: (Data?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        let onFinish: (Data?) -> Void
        init(onFinish: @escaping (Data?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            // JPEG at full quality here; ImagePrep does the real downscale and
            // strips the metadata. Handing it a lossy re-encode would only
            // stack two generations of artefacts.
            onFinish(image?.jpegData(compressionQuality: 1.0))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

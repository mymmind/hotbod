import PhotosUI
import SwiftUI
import UIKit

/// Shared Add Photo flow: Take Photo / Choose from Library → image `Data` callback.
struct BodyPhotoAddPhotoModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onImageData: (Data) async -> Void
    var onFailure: ((String) -> Void)?

    @State private var showLibraryPicker = false
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var pickerItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Add Photo", isPresented: $isPresented, titleVisibility: .visible) {
                Button("Take Photo") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCamera = true
                    } else {
                        showCameraUnavailable = true
                    }
                }
                .accessibilityIdentifier("bodyPhoto.takePhoto")
                Button("Choose from Library") {
                    showLibraryPicker = true
                }
                .accessibilityIdentifier("bodyPhoto.chooseLibrary")
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showLibraryPicker, selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { _, item in
                Task {
                    defer { pickerItem = nil }
                    guard let item else { return }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else {
                            onFailure?("Could not load that photo. Try a different image.")
                            return
                        }
                        await onImageData(data)
                    } catch {
                        onFailure?("Could not load that photo. Try a different image.")
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraImagePicker(
                    onImage: { image in
                        showCamera = false
                        Task {
                            guard let data = BodyPhotoImageProcessor.jpegData(from: image) else {
                                onFailure?("Could not process that photo. Try again.")
                                return
                            }
                            await onImageData(data)
                        }
                    },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .alert("Camera Unavailable", isPresented: $showCameraUnavailable) {
                Button("Choose from Library") {
                    showLibraryPicker = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This device cannot take photos. Choose an image from your library instead.")
            }
    }
}

extension View {
    func bodyPhotoAddPhoto(
        isPresented: Binding<Bool>,
        onImageData: @escaping (Data) async -> Void,
        onFailure: ((String) -> Void)? = nil
    ) -> some View {
        modifier(
            BodyPhotoAddPhotoModifier(
                isPresented: isPresented,
                onImageData: onImageData,
                onFailure: onFailure
            )
        )
    }
}

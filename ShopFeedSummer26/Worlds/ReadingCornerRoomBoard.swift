import ImageIO
import PhotosUI
import SwiftUI

/// An illustrative cutout composition. Photos and positions are session-local;
/// capability details live behind Info, not on the invitation card.
struct ReadingCornerRoomBoard: View {
    let selection: ReadingCornerSelection
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var roomImage: UIImage?
    @State private var error: String?
    @State private var isLoading = false
    @State private var showsInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Arrange your corner.")
                        .font(GravityFont.expressiveBold.fixedFont(size: 30)).tracking(-0.7)
                    ReadingCornerRoomScene(pieces: selection.selected, roomImage: roomImage, interactive: true)
                        .frame(height: 390).clipShape(RoundedRectangle(cornerRadius: 24))
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Your room preview")
                        .accessibilityIdentifier("corner.room-board")
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label(isLoading ? "Loading photo…" : (roomImage == nil ? "Add your room photo" : "Change room photo"),
                              systemImage: "photo.on.rectangle")
                            .font(GravityFont.semiBold.fixedFont(size: 16)).frame(maxWidth: .infinity).padding(16)
                    }
                    .buttonStyle(.borderedProminent).tint(.black).disabled(isLoading)
                    if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                    HStack {
                        Text("Your selected set").font(GravityFont.semiBold.fixedFont(size: 17))
                        Spacer()
                        Text(ReadingCornerCatalog.money(selection.subtotalCents)).font(GravityFont.semiBold.fixedFont(size: 17))
                    }
                    ForEach(selection.selected) { piece in
                        HStack {
                            Text(piece.product.title)
                            Spacer()
                            Text(ReadingCornerCatalog.money(piece.amountCents))
                        }.font(GravityFont.regular.fixedFont(size: 14))
                    }
                }.padding(20)
            }
            .modifier(WorldDragScrollLock())
            .navigationTitle("See it in your room").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showsInfo = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("About this room preview")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .alert("About this preview", isPresented: $showsInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Arrange background-removed product photographs in an illustrative room or your own photo. This is not measured placement or a fit check. Your photo stays in this session and is not uploaded. Prices are USD item subtotals before shipping and tax.")
            }
        }
        .environment(\.colorScheme, .light)
        .task(id: photo) {
            guard let photo else { return }
            isLoading = true
            error = nil
            defer { isLoading = false }
            do {
                guard let data = try await photo.loadTransferable(type: Data.self), !Task.isCancelled,
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1600,
                      ] as CFDictionary) else {
                    if !Task.isCancelled { error = "Couldn’t load that photo. Please choose another." }
                    return
                }
                roomImage = UIImage(cgImage: image)
            } catch { self.error = "Couldn’t load that photo. Please choose another." }
        }
    }
}

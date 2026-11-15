import SwiftUI
import PhotosUI

/// Image picker used for the business logo, the profile photo and product photos (JPG or PNG, up to 2 MB).
struct LogoPicker: View {
    @Binding var data: Data?
    var maxBytes = 2_000_000
    @State private var item: PhotosPickerItem?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.m) {
                Group {
                    if let data, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo").foregroundStyle(.wbMuted)
                    }
                }
                .frame(width: 64, height: 64)
                .background(.wbSoft)
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                VStack(alignment: .leading, spacing: Space.xs) {
                    PhotosPicker(selection: $item, matching: .images) {
                        Text(data == nil ? "Upload" : "Replace").font(.subheadline.weight(.semibold))
                    }
                    if data != nil {
                        Button("Remove", role: .destructive) { data = nil; item = nil }.font(.subheadline)
                    }
                }
                Spacer()
            }
            Text(error ?? "JPG or PNG up to 2 MB")
                .font(.footnote).foregroundStyle(error == nil ? Color.wbMuted : Color.wbRed)
        }
        .onChange(of: item) { _, newItem in
            Task {
                guard let newItem, let loaded = try? await newItem.loadTransferable(type: Data.self) else { return }
                if loaded.count > maxBytes { error = "That file is larger than 2 MB."; item = nil } else { error = nil; data = loaded }
            }
        }
    }
}

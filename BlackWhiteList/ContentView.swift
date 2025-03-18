import SwiftUI
import OSLog

private let logger = Logger()


// MARK: - 資料模型
struct BlacklistItem: Identifiable, Equatable {
  let id = UUID()
  let name: String
  let hashtag: String
}

extension BlacklistItem {
  static func == (lhs: BlacklistItem, rhs: BlacklistItem) -> Bool {
    return lhs.name == rhs.name && lhs.hashtag == rhs.hashtag
  }
}

class BlacklistStore: ObservableObject {
  @Published var items: [BlacklistItem] = []
}
class HashtagStore: ObservableObject {
  @Published var hashtags: [String]
  let presetCategories: [PresetCategory]

  init() {
    // 定義預設常用分類
    let presets: [PresetCategory] = [
      PresetCategory(category: "#中國台灣", items: ["L'Oreal", "Estée Lauder", "資生堂"]),
      PresetCategory(category: "#中資", items: ["中資店1", "中資店2"]),
      PresetCategory(category: "#食安", items: ["味全", "食安店B"]),
      PresetCategory(category: "#厭女", items: ["麥當勞", "食安店B"]),
    ]
    self.presetCategories = presets

    // 取得預設分類的 hashtag 順序
    let presetOrder = presets.map { $0.category }

    // 如果有額外的自訂 hashtag，這裡可以加入，現階段暫無其他自訂項目
    let extraCustom: [String] = []

    // 合併結果：先顯示 #自訂，再顯示預設分類，再顯示其他自訂
    self.hashtags = presetOrder + extraCustom
  }
}

struct PresetCategory: Identifiable {
  let id = UUID()
  let category: String
  let items: [String]
}

// MARK: - 黑名單編輯頁面
struct BlacklistEditView: View {
  @EnvironmentObject var store: BlacklistStore
  @EnvironmentObject var hashtags: HashtagStore
  @State private var newItem: String = ""  // 使用者正在輸入的文字
  @State private var selectedHashtag: String = "#hashtag"
  @State private var showingAddHashtagSheet: Bool = false
  @State private var newHashtagInput: String = ""
  @State private var showPresetList: Bool = false

  var body: some View {
    VStack {
      // 文字輸入與新增按鈕
      HStack {
        TextField("輸入店家名稱", text: $newItem)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding(.horizontal)
        Menu {
          ForEach(hashtags.hashtags, id: \.self) { tag in
            Button(action: {
              selectedHashtag = tag
            }) {
              Text(tag)
            }
          }
          Divider()
          Button(action: {
            showingAddHashtagSheet = true
          }) {
            Text("新增 hashtag")
          }
          
        } label: {
          HStack {
            Text(selectedHashtag)
            Image(systemName: "chevron.down")
          }
          .padding(8)
          .background(Color(.systemGray5))
          .cornerRadius(8)
        }
        Button(action: {
          // 這裡可加入自動補全或驗證邏輯
          if !newItem.isEmpty {
            store.items.append(
              BlacklistItem(name: newItem, hashtag: selectedHashtag))
            newItem = ""
          }
        }) {
          Image(systemName: "plus.circle.fill")
            .font(.title)
        }
        .padding(.trailing)
      }
      .padding(.vertical)

      // 列表顯示已加入的店家
      List {
        ForEach(store.items.sorted(by: { $0.hashtag < $1.hashtag })) { item in
          HStack {
            Text(item.name)
            Spacer()
            Text(item.hashtag)
              .foregroundColor(.secondary)
          }
        }
        .onDelete(perform: deleteItems)
      }

      // 預設常用項目選取按鈕
      Button(action: {
        showPresetList.toggle()
      }) {
        Text("選取常用黑名單")
          .font(.headline)
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.red.opacity(0.8))
          .foregroundColor(.white)
          .cornerRadius(8)
          .padding(.horizontal)
      }
      .padding(.bottom)
      .sheet(isPresented: $showPresetList) {
        PresetCategoryListView(presetCategories: hashtags.presetCategories) {
          blacklistItem in
          if !store.items.contains(where: {
            $0.name == blacklistItem.name && $0.hashtag == blacklistItem.hashtag
          }) {
            store.items.append(blacklistItem)
          }
        }
      }
      .sheet(isPresented: $showingAddHashtagSheet) {
        AddHashtagView(
          newHashtag: $newHashtagInput,
          onComplete: {
            if !newHashtagInput.isEmpty
                && !hashtags.hashtags.contains(newHashtagInput)
            {
              newHashtagInput = "#" + newHashtagInput
              hashtags.hashtags.append(newHashtagInput)
              selectedHashtag = newHashtagInput
            }
            newHashtagInput = ""
            showingAddHashtagSheet = false
          },
          onCancel: {
            newHashtagInput = ""
            showingAddHashtagSheet = false
          })
      }
    }
    .navigationTitle("編輯黑名單")
  }

  // 刪除功能
  func deleteItems(at offsets: IndexSet) {
    store.items.remove(atOffsets: offsets)
  }
}

// MARK: - 預設分類列表頁面
struct PresetCategoryListView: View {
  let presetCategories: [PresetCategory]
  // 點選店家後的回傳處理
  let selectionHandler: (BlacklistItem) -> Void
  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    NavigationView {
      List(presetCategories) { category in
        NavigationLink(
          destination: PresetItemsView(
            presetCategory: category,
            selectionHandler: { selectedItem in
              selectionHandler(selectedItem)
              presentationMode.wrappedValue.dismiss()
            })
        ) {
          Text(category.category)
            .font(.headline)
        }
      }
      .navigationTitle("選擇預設分類")
    }
  }
}

// MARK: - 預設分類中的項目列表頁面
struct PresetItemsView: View {
  let presetCategory: PresetCategory
  let selectionHandler: (BlacklistItem) -> Void
  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    List(presetCategory.items, id: \.self) { item in
      Button(action: {
        selectionHandler(
          BlacklistItem(name: item, hashtag: presetCategory.category))
        presentationMode.wrappedValue.dismiss()
      }) {
        Text(item)
      }
    }
    .navigationTitle(presetCategory.category)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("全選") {
          for item in presetCategory.items {
            selectionHandler(
              BlacklistItem(name: item, hashtag: presetCategory.category))
          }
          presentationMode.wrappedValue.dismiss()
        }
      }
    }
  }
}

// MARK: - 白名單編輯頁面 (保持原有簡易版)
struct WhitelistEditView: View {
  @State private var items: [String] = []
  @State private var newItem: String = ""
  @State private var showPresetList = false

  // 假設的常用白名單項目
  let presetItems = ["全家便利商店", "家樂福", "Costco"]

  var body: some View {
    VStack {
      HStack {
        TextField("輸入店家名稱", text: $newItem)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding(.horizontal)
        Button(action: {
          if !newItem.isEmpty {
            items.append(newItem)
            newItem = ""
          }
        }) {
          Image(systemName: "plus.circle.fill")
            .font(.title)
        }
        .padding(.trailing)
      }
      .padding(.vertical)

      List {
        ForEach(items, id: \.self) { item in
          Text(item)
        }
        .onDelete(perform: deleteItems)
      }

      Button(action: {
        showPresetList.toggle()
      }) {
        Text("選取常用白名單")
          .font(.headline)
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.green.opacity(0.8))
          .foregroundColor(.white)
          .cornerRadius(8)
          .padding(.horizontal)
      }
      .padding(.bottom)
      .sheet(isPresented: $showPresetList) {
        PresetListView(items: presetItems) { selected in
          if !items.contains(selected) {
            items.append(selected)
          }
        }
      }
    }
    .navigationTitle("編輯白名單")
  }

  func deleteItems(at offsets: IndexSet) {
    items.remove(atOffsets: offsets)
  }
}

// 舊版簡單預設清單 (白名單用)
struct PresetListView: View {
  let items: [String]
  let selectionHandler: (String) -> Void
  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    NavigationView {
      List(items, id: \.self) { item in
        Button(action: {
          selectionHandler(item)
          presentationMode.wrappedValue.dismiss()
        }) {
          Text(item)
        }
      }
      .navigationTitle("選擇預設項目")
    }
  }
}

// MARK: - 新增 hashtag 視圖
struct AddHashtagView: View {
  @Binding var newHashtag: String
  var onComplete: () -> Void
  var onCancel: () -> Void

  var body: some View {
    NavigationView {
      VStack {
        TextField("輸入新的 hashtag", text: $newHashtag)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding()
        Spacer()
      }
      .navigationTitle("新增 hashtag")
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("取消", action: onCancel)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("加入", action: onComplete)
        }
      }
    }
  }
}

// MARK: - 主畫面
struct ContentView: View {
  var body: some View {
    NavigationView {
      VStack(spacing: 40) {
        NavigationLink(destination: BlacklistEditView()) {
          Text("黑名單")
            .font(.largeTitle)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }

        NavigationLink(destination: WhitelistEditView()) {
          Text("白名單")
            .font(.largeTitle)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }
      }
      .navigationTitle("黑白名單管理")
    }
    .environmentObject(BlacklistStore())
    .environmentObject(HashtagStore())
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

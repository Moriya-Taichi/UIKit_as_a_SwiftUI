# UIKitSwiftUI

[![CI](https://github.com/Moriya-Taichi/UIKit_as_a_SwiftUI/actions/workflows/ci.yml/badge.svg)](https://github.com/Moriya-Taichi/UIKit_as_a_SwiftUI/actions/workflows/ci.yml)

UIKitの任意のビューを、具体型を消さずにSwiftUIへ組み込むためのSwift Packageです。iOS 16を最小対象とし、Xcode 16のiOS 18 SDKとXcode 27のiOS 27 SDKで継続的にビルドします。iOS 16.4シミュレータでのテストも実行します。

## 対応範囲

「UIKitを全て」は、UIKitモジュールに含まれる全シンボルへ個別ラッパーを作るという意味ではありません。`UIImage`、`UIFont`、delegate、layout constraintなどはビューではないため、`UIViewRepresentable`にはできません。このパッケージはUIKitの表示要素を次のように漏れなく扱います。

| UIKitの型 | SwiftUIブリッジ |
|---|---|
| 任意の`UIView`サブクラス | `UIKitView<ViewType>` |
| coordinatorが必要な`UIView` | `UIKitCoordinatedView<ViewType, Coordinator>` |
| 任意の`UIControl`サブクラス | `UIKitControl<ControlType>` |
| 任意の`UIViewController`サブクラス | `UIKitViewController<ControllerType>` |
| coordinatorが必要な`UIViewController` | `UIKitCoordinatedViewController<ControllerType, Coordinator>` |
| `UITextField`（モデル駆動） | `UIKitTextFieldModel` + `UIKitTextField(model:)` |
| `UITextView`（モデル駆動） | `UIKitTextViewModel` + `UIKitTextView(model:)` |
| `UISearchBar`（モデル駆動） | `UIKitSearchBarModel` + `UIKitSearchBar(model:)` |
| `UITableView`のdata source | `UIKitListModel` + `UIKitTableView(model:)` |
| `UICollectionView`のdata source | `UIKitListModel` + `UIKitCollectionView(model:)` |

`UIViewController`は`UIViewRepresentable`で包むとcontainmentとappearance lifecycleが壊れるため、Appleの設計どおり`UIViewControllerRepresentable`を使います。

ジェネリックな中核APIなので、アプリ独自の`UIView`やiOS 27 SDKで追加された`UIView`も、ライブラリ側の更新なしで利用できます。Appleの公開SDK番号はiOS 18の次がiOS 26であり、iOS 19〜25という公開SDKはありません。

## 必要環境

- iOS 16以降、またはMac Catalyst 16以降
- Observableモデル層（`*Model`、`*Deciding`、`UIKitTableView`、`UIKitCollectionView`）はiOS 17以降。それ以外はiOS 16から使えます
- Swift 6 / Xcode 16以降
- iOS 27固有APIを使う場合はXcode 27

## インストール

Xcodeの **File > Add Package Dependencies** から次のURLを追加します。

```text
https://github.com/Moriya-Taichi/UIKit_as_a_SwiftUI.git
```

```swift
import UIKitSwiftUI
```

## 任意のUIViewを使う

```swift
struct ProfileTitle: View {
    let name: String

    var body: some View {
        UIKitView(make: UILabel.init)
            .setting(\.text, to: name)
            .setting(\.numberOfLines, to: 0)
            .configure {
                $0.font = .preferredFont(forTextStyle: .title1)
                $0.adjustsFontForContentSizeCategory = true
            }
            .accessibility(
                UIKitAccessibility(
                    identifier: "profile-title",
                    label: name,
                    traits: .header
                )
            )
            .measuringWithAutoLayout()
    }
}
```

既存インスタンスも具体型を保ったまま包めます。

```swift
let label = UILabel()
let swiftUIView: UIKitView<UILabel> = UIKitBridge.view(label)
```

## delegateやdataSourceを使う

```swift
final class PickerCoordinator: NSObject, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(
        _ pickerView: UIPickerView,
        numberOfRowsInComponent component: Int
    ) -> Int { 10 }
}

let picker = UIKitCoordinatedView(
    makeCoordinator: PickerCoordinator.init,
    make: { coordinator, _ in
        let picker = UIPickerView()
        picker.dataSource = coordinator
        return picker
    },
    dismantle: { picker, coordinator in
        if picker.dataSource === coordinator {
            picker.dataSource = nil
        }
    }
)
```

## SwiftUI Binding付きコントロール

```swift
struct Controls: View {
    @State private var volume: Float = 0.5
    @State private var enabled = true
    @State private var query = ""

    var body: some View {
        VStack {
            UIKitSlider(value: $volume)
            UIKitSwitch(isOn: $enabled)
            UIKitTextField("Search", text: $query)
        }
    }
}
```

次の型は`Binding`とUIKitイベントの双方向同期を標準で備えています。

- `UIKitSlider`
- `UIKitSwitch`
- `UIKitStepper`
- `UIKitPageControl`
- `UIKitSegmentedControl`
- `UIKitDatePicker`
- `UIKitColorWell`
- `UIKitTextField`
- `UIKitTextView`
- `UIKitSearchBar`
- `UIKitButton`

独自の`UIControl`には`UIKitControl`を使います。`UIAction`は一度だけ登録され、SwiftUIの更新時に重複せず、dismantle時に解除されます。

## Observableモデルで使う

このモデル層（`*Model`、`*Deciding`、`UIKitTableView`、`UIKitCollectionView`、および各ブリッジの`init(model:)`）は`@Observable`を使うためiOS 17以降が必要です。パッケージの最小対象はiOS 16のままで、それ以外のAPIはiOS 16から使えるので、以下の例は`@available`や`if #available`のガード下で利用してください。

WebKitのSwiftUI版`WebPage`と同じ発想で、`@Observable`なモデルがデータとポリシーを所有し、ビューは表示に徹します。テキスト、フォーカス、選択状態、そして「許可するかどうか」の判断はモデル側にあり、ブリッジはモデルとUIKitインスタンスを同期するだけです。

判断が必要なdelegateメソッドは`UIKitTextFieldDeciding`のような`*Deciding`プロトコルになります。全ての要件に許可側のデフォルト実装があるので、必要な判断だけを実装します。deciderはモデルの初期化時に渡してモデルが保持し、ブリッジがdeciderに直接触れることはありません。

通知的なdelegateコールバックは`model.events`という単一の`AsyncStream`に流れます。**単一コンシューマ**なので、購読するtaskは1つだけにしてください。2つ目のコンシューマは自分用のコピーを受け取るのではなく、要素を奪い合います。

```swift
struct PhoneNumberField: View {
    struct DigitsOnly: UIKitTextFieldDeciding {
        func shouldChangeText(
            in range: NSRange,
            replacement: String,
            textField: UITextField
        ) -> Bool {
            replacement.isEmpty || replacement.allSatisfy(\.isNumber)
        }
    }

    @State private var model = UIKitTextFieldModel(decider: DigitsOnly())

    var body: some View {
        UIKitTextField("電話番号", model: model)
            .task {
                for await event in model.events {
                    switch event {
                    case .textChanged(let text):
                        print("入力中: \(text)")
                    case .submitted:
                        print("確定: \(model.text)")
                    case .editingBegan, .editingEnded, .cleared:
                        break
                    }
                }
            }
    }
}
```

`UIKitTextViewModel`と`UIKitSearchBarModel`も同じ形です。

table viewとcollection viewでは`UIKitListModel`がsectionとitemを所有し、ブリッジがdiffable data sourceのsnapshotへ変換します。`UITableViewDataSource`や`UICollectionViewDataSource`を実装する必要はありません。`model.items`を書き換えれば表示が更新され、選択は`model.selectedItems`と`model.events`から届きます。itemの同一性は値の同一性なので、値が変わったitemはdiffにとって別のitemになります。itemはそれ自身がdiffableの識別子であるため、section内だけでなくモデル全体で一意な値にしてください。重複はプログラマエラーで、debugビルドではassertionが発火します。in-placeな更新が必要な場合は、安定した識別子だけを持つitem型を使ってください。

```swift
struct FruitList: View {
    @State private var model = UIKitListModel<Int, String>(
        items: ["apple", "banana"]
    )

    var body: some View {
        VStack {
            UIKitTableView(
                model: model,
                style: .insetGrouped,
                content: { item in
                    var configuration = UIListContentConfiguration.cell()
                    configuration.text = item
                    return configuration
                }
            )
            Button("追加") {
                model.items.append("cherry")
            }
            Text("選択中: \(model.selectedItems.joined(separator: ", "))")
        }
        .task {
            for await event in model.events {
                if case .selected(let item) = event {
                    print("選択: \(item)")
                }
            }
        }
    }
}
```

`UIKitCollectionView(model:layout:content:)`も同じ`UIKitListModel`をそのまま使えます。

既存の`Binding`やクロージャを使うAPIはそのまま利用できます。モデルを使わない軽い用途にはそちらが向いています。ただし1つのブリッジインスタンスで両方が混ざることはなく、`model:`で作ったインスタンスは`Binding`の引数を無視します。

## 初期化が特殊なビュー

`UIKitViewCatalog`には、collection view、table view、calendar view、visual effect view、各種barなどの型付きfactoryがあります。catalogにないビューも`UIKitView(make:update:)`で同じように扱えます。

`UIKitViewCatalog.contentUnavailableView`はiOS 17以降が必要なため、`@available`や`if #available`のガード下で使用してください。

```swift
struct EmptyResults: View {
    var body: some View {
        if #available(iOS 17.0, macCatalyst 17.0, *) {
            UIKitViewCatalog.contentUnavailableView(
                configuration: .search()
            )
        } else {
            Text("No Results")
        }
    }
}
```

```swift
UIKitViewCatalog.collectionView {
    UICollectionViewCompositionalLayout { _, _ in
        // sectionを返す
        nil
    }
}
```

## ライフサイクルと性能

- UIKitインスタンスの生成は`make`だけで行い、SwiftUIの再評価では再生成しません。
- 状態反映は`update`で行い、delegateやtargetはcoordinatorに保持します。
- text inputは値が変わったときだけUIKitへ書き戻し、選択範囲の不要なリセットを避けます。
- `AnyView`や`UIView`への型消去を行いません。
- `sizeThatFits`またはAuto Layoutによる測定を選べます。

## License

MIT

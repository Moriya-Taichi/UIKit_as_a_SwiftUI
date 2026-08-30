# UIKitSwiftUI

[![CI](https://github.com/Moriya-Taichi/UIKit_as_a_SwiftUI/actions/workflows/ci.yml/badge.svg)](https://github.com/Moriya-Taichi/UIKit_as_a_SwiftUI/actions/workflows/ci.yml)

UIKitの任意のビューを、具体型を消さずにSwiftUIへ組み込むためのSwift Packageです。iOS 16を最小対象とし、Xcode 16のiOS 18 SDKとXcode 27のiOS 27 SDKで継続的にビルドします。

## 対応範囲

「UIKitを全て」は、UIKitモジュールに含まれる全シンボルへ個別ラッパーを作るという意味ではありません。`UIImage`、`UIFont`、delegate、layout constraintなどはビューではないため、`UIViewRepresentable`にはできません。このパッケージはUIKitの表示要素を次のように漏れなく扱います。

| UIKitの型 | SwiftUIブリッジ |
|---|---|
| 任意の`UIView`サブクラス | `UIKitView<ViewType>` |
| coordinatorが必要な`UIView` | `UIKitCoordinatedView<ViewType, Coordinator>` |
| 任意の`UIControl`サブクラス | `UIKitControl<ControlType>` |
| 任意の`UIViewController`サブクラス | `UIKitViewController<ControllerType>` |
| coordinatorが必要な`UIViewController` | `UIKitCoordinatedViewController<ControllerType, Coordinator>` |

`UIViewController`は`UIViewRepresentable`で包むとcontainmentとappearance lifecycleが壊れるため、Appleの設計どおり`UIViewControllerRepresentable`を使います。

ジェネリックな中核APIなので、アプリ独自の`UIView`やiOS 27 SDKで追加された`UIView`も、ライブラリ側の更新なしで利用できます。Appleの公開SDK番号はiOS 18の次がiOS 26であり、iOS 19〜25という公開SDKはありません。

## 必要環境

- iOS 16以降、またはMac Catalyst 16以降
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

## 初期化が特殊なビュー

`UIKitViewCatalog`には、collection view、table view、calendar view、visual effect view、各種barなどの型付きfactoryがあります。catalogにないビューも`UIKitView(make:update:)`で同じように扱えます。

`UIKitViewCatalog.contentUnavailableView`はiOS 17以降が必要なため、`@available`や`if #available`のガード下で使用してください。

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

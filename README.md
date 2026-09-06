# UIKitSwiftUI

[![CI](https://github.com/Moriya-Taichi/UIKit_as_a_SwiftUI/actions/workflows/ci.yml/badge.svg)](https://github.com/Moriya-Taichi/UIKit_as_a_SwiftUI/actions/workflows/ci.yml)

UIKit / AppKit のビューやビューコントローラを、具体型を保ったまま SwiftUI に組み込むための Swift Package です。

ジェネリックなブリッジを中心に、SwiftUI の `Binding` に対応した標準コントロールや、状態とイベントをまとめて扱う Observable モデルを提供します。UIKit の標準ビューだけでなく、アプリ独自の `UIView` や新しい SDK で追加されたビューも、ライブラリの更新を待たずに利用できます。

macOSネイティブのアプリには `AppKitSwiftUI`、iOS / Mac Catalystには `UIKitSwiftUI` を使います。AppKitの利用方法は [AppKitガイド](Documentation/AppKit.md) を参照してください。以下のUIKit APIは引き続き利用できます。

## API の選び方

| 用途 | API |
| --- | --- |
| 任意の `UIView` を表示する | `UIKitView<ViewType>` |
| デリゲートやデータソースを持つ `UIView` を表示する | `UIKitCoordinatedView<ViewType, Coordinator>` |
| 任意の `UIControl` とイベントを接続する | `UIKitControl<ControlType>` |
| 任意の `UIViewController` を表示する | `UIKitViewController<ControllerType>` |
| コーディネータを持つ `UIViewController` を表示する | `UIKitCoordinatedViewController<ControllerType, Coordinator>` |
| 標準コントロールを `Binding` と同期する | `UIKitSlider`、`UIKitSwitch`、`UIKitTextField` など |
| テキスト入力をモデル駆動で扱う | `UIKitTextFieldModel`、`UIKitTextViewModel`、`UIKitSearchBarModel` |
| データと選択状態からSwiftUIの行を表示する | `UIKitTableView(data, selection:)` / `UIKitCollectionView(data, selection:layout:)` |
| リストをモデル駆動で扱う | `UIKitListModel` と `UIKitTableView` / `UIKitCollectionView` |
| 特殊なイニシャライザを持つビューを生成する | `UIKitViewCatalog` |

`UIViewController` のブリッジには `UIViewControllerRepresentable` を使用します。`UIViewRepresentable` で包むことによる親子関係や表示ライフサイクルの破損を避け、UIKit 本来の動作を維持します。

## 対応環境

- `UIKitSwiftUI`: iOS 16 以降、または Mac Catalyst 16 以降
- `AppKitSwiftUI`: macOS 13 以降
- Swift 6 / Xcode 16 以降
- Observable モデルを使う API は iOS 17 以降
- iOS 27 固有の API を使う場合は Xcode 27

CIではXcode 16 / 27でiOS・Mac Catalyst・ネイティブmacOSをビルドし、iOS 16.4を含むシミュレータとmacOS上でテストします。macOS 13はデプロイメントターゲットであり、macOS 13実機での実行検証を意味しません。

## インストール

Xcode の **File > Add Package Dependencies** から、次の URL を追加します。

```text
https://github.com/Moriya-Taichi/UIKit_as_a_SwiftUI.git
```

アプリのターゲットに対応するライブラリ製品を追加し、モジュールをインポートしてください。

```swift
import UIKitSwiftUI
```

## AppKitを使う

macOSアプリでは `AppKitSwiftUI` 製品を追加します。UIKitと同じように、状態を初期化子へ渡し、設定を修飾子で指定できます。

```swift
import AppKitSwiftUI

struct MacEditor: View {
    @State private var name = ""
    @State private var volume = 0.5
    @State private var enabled = true

    var body: some View {
        VStack {
            AppKitTextField("名前", text: $name)
                .textFieldBezelStyle(.roundedBezel)
            AppKitSlider(value: $volume)
                .sliderContinuousUpdates(true)
            AppKitToggle("有効", isOn: $enabled)
            AppKitTextView(text: $name)
        }
        .padding()
    }
}
```

任意の `NSView` には `AppKitView`、`NSViewController` には `AppKitViewController` を使います。`AppKitTableView` / `AppKitCollectionView` には、データ・ID・選択Binding・SwiftUIの行を渡せます。詳細とUIKit版との対応表は [AppKitガイド](Documentation/AppKit.md) にまとめています。

## UIKitの基本的な使い方

`UIKitView` の `make` で UIKit ビューを生成し、修飾子または `update` クロージャで状態を反映します。具体型は消去されないため、`UILabel` 固有のプロパティにもそのままアクセスできます。

```swift
struct ProfileTitle: View {
    let name: String

    var body: some View {
        UIKitView(make: UILabel.init)
            .text(name)
            .configureUIKit {
                $0.font = .preferredFont(forTextStyle: .title1)
                $0.adjustsFontForContentSizeCategory = true
            }
            .measuringWithAutoLayout()
            .lineLimit(2)
            .accessibilityIdentifier("profile-title")
            .accessibilityLabel(name)
            .accessibilityAddTraits(.isHeader)
    }
}
```

外部で所有している既存インスタンスも、その具体型を保ったまま包めます。

```swift
let label = UILabel()
let swiftUIView: UIKitView<UILabel> = UIKitBridge.view(label)
```

### デリゲートやデータソースを使う

デリゲートやデータソースなど、ビューと同じ期間だけ保持するオブジェクトが必要な場合は `UIKitCoordinatedView` を使います。

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

## 標準コントロールを Binding と同期する

UIKit の標準コントロールを SwiftUI の状態と双方向に同期するラッパーを用意しています。

```swift
struct Controls: View {
    @State private var volume: Double = 0.5
    @State private var isEnabled = true
    @State private var query = ""

    var body: some View {
        VStack {
            UIKitSlider(value: $volume)
            UIKitSwitch(isOn: $isEnabled)
            UIKitTextField("Search", text: $query)
        }
    }
}
```

利用できるラッパーは次のとおりです。

- `UIKitSlider`、`UIKitSwitch`、`UIKitStepper`
- `UIKitPageControl`、`UIKitSegmentedControl`
- `UIKitDatePicker`、`UIKitColorWell`
- `UIKitTextField`、`UIKitTextView`、`UIKitSearchBar`
- `UIKitButton`

独自の `UIControl` には `UIKitControl` を使います。内部の `UIAction` は一度だけ登録され、SwiftUI の更新時に重複せず、ビューの破棄時に解除されます。

## 修飾子で設定する

よく使うUIKit固有の設定には、具体型に応じた修飾子を用意しています。標準のSwiftUI修飾子とも組み合わせられます。

```swift
UIKitTextField(localized: "名前", text: $name)
    .textFieldBorderStyle(.roundedRect)
    .textFieldClearButtonMode(.whileEditing)
    .uiKitKeyboardType(.default)
    .uiKitReturnKeyType(.done)
    .padding()
    .disabled(isSaving)
    .onUIKitSubmit {
        save(name)
    }
```

`configureUIKit`は、汎用ビュー・コントロール・入力・リストの各ブリッジで利用できる共通の設定口です。更新のたびに呼ばれるため、ビュー生成やイベント登録はここで行わず、バインドされた値やブリッジが所有するデリゲート・データソースも上書きしないでください。ビューコントローラにも同名の設定メソッドがあります。

具体型に対する修飾子は、上の例のように`padding`などの一般的な修飾子より先に指定します。`onUIKitSubmit`は任意の`View`に適用でき、親から子の`UIKitTextField`と`UIKitSearchBar`の送信を受け取れます。Binding方式とモデル方式の両方で動作し、`model.events`を消費しません。標準の`onSubmit`とは別の通知で、`submitScope`の対象にはなりません。

親の`disabled`と`scrollDisabled`は内部のUIKitビューにも反映されます。有効状態とスクロール可否は標準修飾子で指定してください。対応するUIKitプロパティへの直接代入よりEnvironmentを優先します。ラベルは`lineLimit`を参照し、`nil`なら行数を制限しません。明示的な`numberOfLines`や`configureUIKit`による行数指定がある場合は、その設定を優先します。SwiftUIの`Font`や`ShapeStyle`をUIKitへ任意に変換するAPIは提供していません。

表示文字列には`localized:`と`verbatim:`を選べます。`UIKitSearchBar`では`localizedPrompt:` / `verbatimPrompt:`、セグメントでは`localizedTitle:`を使います。ローカライズはSwiftUIの`locale`を使って更新されます。既存の`String`を受け取る初期化子の意味は変わりません。

セグメントの選択には、表示位置に依存しない値を使えます。

```swift
enum Filter: String, CaseIterable {
    case all, favorites
}

// selectionはBinding<Filter>またはBinding<Filter?>
UIKitSegmentedControl(Filter.allCases, selection: $filter) { $0.rawValue }
```

日付ピッカーのラベル付き初期化子は、SwiftUIの`DatePickerComponents`を受け取ります。

```swift
UIKitDatePicker("誕生日", selection: $birthday, displayedComponents: [.date])
    .uiKitDatePickerStyle(.wheels)
```

既存のラベルなし初期化子の`displayedComponents:`は引き続き`UIDatePicker.Mode`です。UIKitのモードを直接指定する新しいコードでは`mode:`も利用できます。Sliderは`Double`などの浮動小数点Bindingを受け取れますが、UIKit内部の値とユーザー操作による書き戻しの精度は`Float`です。

## データからSwiftUIの行を表示する

iOS 17以降では、専用モデルを用意せず、データと選択Bindingを直接渡せます。

```swift
@available(iOS 17.0, macCatalyst 17.0, *)
struct UserList: View {
    struct User: Identifiable {
        let id: Int
        var name: String
    }

    @State private var users = [
        User(id: 1, name: "Alice"),
        User(id: 2, name: "Bob"),
    ]
    @State private var selectedIDs: Set<User.ID> = []

    var body: some View {
        UIKitTableView(users, selection: $selectedIDs) { user in
            Label(user.name, systemImage: "person")
        }
    }
}
```

単一選択には`Binding<ID?>`、複数選択には`Binding<Set<ID>>`を渡します。選択が不要なら`selection:`を省略できます。`Identifiable`でないデータには`id:`キーパスを指定します。IDは`Hashable & Sendable`かつ全行で一意である必要がありますが、表示データ自体にこれらの準拠は不要です。

行は`UIHostingConfiguration`で表示され、親のEnvironmentも引き継ぎます。内容を変更してもIDが同じなら行を更新し、選択を維持します。Binding内のIDを絞り込みによって表示しなくなっても、そのIDをBindingから削除しません。再表示すると選択を復元します。データを完全に削除する場合の選択整理は呼び出し側で行ってください。

`UIKitCollectionView(users, selection:layout:content:)`にも同じ形式で渡せます。複数セクションやUIKitセルの直接設定には、引き続き`UIKitListModel`を使うAPIが適しています。

両リストと、汎用ブリッジで包んだ`UIScrollView`は標準の`refreshable`に対応します。非同期処理の終了に合わせて更新表示を終了し、処理中の重複要求を抑制します。ビューを破棄すると実行中のTaskをキャンセルします。処理側もキャンセルに対応してください。

既存APIからの具体的な移行例と設定の優先順位は、[移行ガイド](Documentation/DeclarativeAPI.md)を参照してください。

## Observable モデルで状態とイベントを扱う

Observable モデルを使う API は iOS 17 以降で利用できます。`@Observable` なモデルがデータと判断ロジックを所有し、ブリッジはモデルと UIKit インスタンスの同期に専念します。単純な双方向同期には `Binding`、入力可否の判断やイベント購読までまとめたい場合にはモデルが適しています。

対象となるのは、`*Model`、`*Deciding`、`UIKitTableView`、`UIKitCollectionView`、および各ブリッジの `init(model:)` です。iOS 16 も対象に含むアプリでは、`@available` または `if #available` で利用箇所を保護してください。

### テキスト入力

入力可否を判断するデリゲートメソッドは、`UIKitTextFieldDeciding` などの `*Deciding` プロトコルとして定義されています。各要件には許可するデフォルト実装があるため、必要な判断だけを実装できます。

通知型のデリゲートコールバックは、モデルの `events` から `AsyncStream` として受け取ります。ストリームは単一コンシューマ向けなので、購読する `Task` は 1 つにしてください。複数の `Task` から購読すると、同じイベントのコピーを受け取るのではなく、イベントを奪い合います。

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

`UIKitTextViewModel` と `UIKitSearchBarModel` も同じ構成で利用できます。

### テーブルビューとコレクションビュー

`UIKitListModel` がセクション、項目、選択状態を所有し、`UIKitTableView` と `UIKitCollectionView` が diffable data source のスナップショットへ変換します。`UITableViewDataSource` や `UICollectionViewDataSource` を実装する必要はありません。

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

`UIKitCollectionView(model:layout:content:)` でも同じ `UIKitListModel` を利用できます。

項目自体が diffable data source の識別子になるため、すべてのセクションを通して一意な値にしてください。値が変化した項目は別の項目とみなされます。表示内容をその場で更新したい場合は、安定した識別子を持つ項目型を使用してください。重複はプログラマエラーとして扱われ、デバッグビルドではアサーションが発生します。

既存の `Binding` やクロージャを使う API も引き続き利用できます。ただし、1 つのブリッジでモデル方式と `Binding` 方式を併用することはできません。`model:` で生成したインスタンスでは、`Binding` 用の引数は使われません。

## 初期化が特殊なビューを使う

`UIKitViewCatalog` は、コレクションビュー、テーブルビュー、カレンダービュー、ビジュアルエフェクトビュー、各種バーなど、イニシャライザが統一されていないビューの型付きファクトリを提供します。カタログにないビューも `UIKitView(make:update:)` で利用できます。

```swift
UIKitViewCatalog.collectionView {
    UICollectionViewCompositionalLayout { _, _ in
        // section を返す
        nil
    }
}
```

`UIKitViewCatalog.contentUnavailableView` は iOS 17 以降で利用できます。

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

## 対応範囲とライフサイクル

このパッケージが扱う「UIKit のすべて」は、UIKit モジュールの全シンボルに個別のラッパーを用意するという意味ではありません。`UIImage`、`UIFont`、デリゲート、レイアウト制約など、表示要素ではない型は `UIViewRepresentable` の対象外です。代わりに、任意の `UIView`、`UIControl`、`UIViewController` をジェネリックな API で扱います。

- UIKit インスタンスは `make` で生成し、SwiftUI の再評価時には再生成しません。
- 状態は `update` で反映し、デリゲートやターゲットはコーディネータが保持します。
- テキスト入力は値が変わった場合だけ UIKit へ書き戻し、選択範囲の不要なリセットを避けます。
- `AnyView` や `UIView` への型消去は行いません。
- サイズ計算には `sizeThatFits` または Auto Layout を利用できます。

## License

MIT

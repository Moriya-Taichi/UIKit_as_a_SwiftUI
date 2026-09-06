# AppKitをSwiftUIで使う

`AppKitSwiftUI` はmacOS 13以降のネイティブAppKit用ライブラリです。iOS / Mac Catalyst用の `UIKitSwiftUI` と同じパッケージに含まれます。macOSアプリのターゲットに `AppKitSwiftUI` 製品を追加し、`import AppKitSwiftUI` で利用します。

## APIの対応

| 用途 | UIKit | AppKit |
|---|---|---|
| 任意のビュー | `UIKitView` | `AppKitView` |
| Coordinator付きビュー | `UIKitCoordinatedView` | `AppKitCoordinatedView` |
| 任意のコントローラ | `UIKitViewController` | `AppKitViewController` |
| Coordinator付きコントローラ | `UIKitCoordinatedViewController` | `AppKitCoordinatedViewController` |
| コントロールのイベント | `UIKitControl` / UIAction | `AppKitControl` / target-action |
| ネイティブ設定 | `configureUIKit` | `configureAppKit` |
| テキスト入力 | `UIKitTextField` | `AppKitTextField` / `AppKitSecureField` |
| 検索入力 | `UIKitSearchBar` | `AppKitSearchField` |
| 複数行入力 | `UIKitTextView` | `AppKitTextView` |
| Return送信 | `onUIKitSubmit` | `onAppKitSubmit` |
| データ・選択付きリスト | `UIKitTableView` / `UIKitCollectionView` | `AppKitTableView` / `AppKitCollectionView` |
| SwiftUIをホストする | `hostedInUIKit` | `hostedInAppKit` |

標準コントロールには `AppKitButton`、`AppKitToggle`（チェックボックス）、`AppKitSwitch`、`AppKitSlider`、`AppKitStepper`、`AppKitSegmentedControl`、`AppKitDatePicker`、`AppKitColorWell` があります。プログレス表示・ラベル・画像・スクロールビュー・視覚効果には `AppKitViewCatalog` を使えます。

## 任意のNSViewを包む

```swift
AppKitView(make: { NSVisualEffectView() })
    .configureAppKit {
        $0.material = .sidebar
        $0.blendingMode = .behindWindow
    }
```

カタログにないクラスも、`NSView` / `NSViewController` のサブクラスであれば汎用ブリッジで包めます。ファクトリはビューの生成時に呼ばれ、`update` と `configureAppKit` はSwiftUIの更新時に呼ばれます。既存インスタンスを包む `AppKitBridge.view` / `controller` も利用できますが、複数の表示場所で同じネイティブインスタンスを共有しないでください。

デリゲートなどを保持する場合は `AppKitCoordinatedView` を使います。`makeCoordinator` で生成した値を更新と破棄にも渡します。所有するデリゲート・通知購読は `dismantle` で解除します。

`configureAppKit` と `setting` は具体型を維持します。`padding` / `frame` など、一般的なSwiftUIのビューに変換する修飾子より先に指定してください。

サイズはSwiftUIとAppKitの標準の計測に任せるか、`measuring` / `sizeThatFits:` で指定します。`measuringWithAutoLayout()` はAppKitの `fittingSize` を使います。幅の提案を含む独自の計測には `measuring` を使います。

## Bindingとイベント

```swift
AppKitSlider(value: $volume) // Doubleをそのまま保持
    .sliderContinuousUpdates(true)

AppKitSegmentedControl(Filter.allCases, selection: $filter) { $0.title }

AppKitDatePicker("誕生日", selection: $birthday, displayedComponents: [.date])
    .appKitDatePickerStyle(.textFieldAndStepper)
```

Sliderは `BinaryFloatingPoint` のBindingを受け、内部ではNSSliderのDoubleを使います。表示だけではBindingへ書き戻しません。StepperはDoubleとIntを受けますが、ネイティブ内部はDoubleなので、巨大なIntを完全な精度で編集する用途には適しません。

セグメントの選択は値で保持し、並べ替えで別の値へ変わりません。値は一意にしてください。オプショナルな選択にも対応し、データにない値は未選択表示にします。

`AppKitControl` はAppKitの単一のtarget/actionを所有します。更新時は最新のクロージャへ差し替え、破棄時は元のtarget/actionへ戻します。元のtargetは弱参照です。外部が別のtarget/actionを装着済みの場合は、その設定を破棄時に上書きしません。マウント中の `configureAppKit` からtarget/actionを設定してもブリッジが再設定します。イベント処理には `onEvent` を使ってください。

Binding付きコントロールでは、Bindingに対応する値・選択をAppKitプロパティへの直接代入より優先します。

## テキスト入力とローカライズ

```swift
AppKitTextField("名前", text: $name)
    .textFieldBezelStyle(.roundedBezel)
    .padding()
    .onAppKitSubmit { save(name) }

AppKitSecureField("パスワード", text: $password)
AppKitSearchField(verbatim: "Search", text: $query)
AppKitTextView(text: $notes)
```

ラベル・プレースホルダーの通常の引数は `LocalizedStringResource`、翻訳しない文字列は `verbatim:` で受けます。文字列リソースのバンドルとキーを維持し、SwiftUIの `locale` の変更に追従します。ラベルには `AppKitView(...).text(localized:)`、セグメントには `localizedTitle:` もあります。

テキスト入力では、変換中のmarked textをBindingから上書きせず、未確定の変換文字列をBindingへ書き戻しません。変換確定後の変更通知で同期します。外部から文字列が変わった場合は選択範囲を文字列の長さに収めます。

`onAppKitSubmit` はテキストフィールド・セキュアフィールド・検索フィールドのReturnを受けます。親から子の順に通知し、初期化子の `onSubmit:` も指定した場合はそれを先に呼びます。標準の `onSubmit` / `submitScope` とは独立しています。検索アイコンのクリックをReturn送信とは扱いません。`AppKitTextView` の改行は送信とは扱いません。

## IDと選択Bindingでリストを作る

```swift
struct Person: Identifiable {
    let id: Int
    var name: String
}

// people: [Person], selectedIDs: Set<Person.ID>
AppKitTableView(people, selection: $selectedIDs) { person in
    Label(person.name, systemImage: "person")
}

AppKitCollectionView(people, selection: $selectedIDs, layout: {
    let layout = NSCollectionViewFlowLayout()
    layout.itemSize = NSSize(width: 200, height: 52)
    return layout
}) { person in
    Text(person.name)
}
```

`Identifiable` でなければ `id: \.identifier` のようなキーパスを指定します。IDに `Hashable` を要求し、表示データ自体には要求しません。単一選択は `Binding<ID?>`、複数選択は `Binding<Set<ID>>` です。選択Bindingを省略すると選択不可になります。

同じIDの内容・Environmentが変わると、既存のNSHostingViewを更新します。IDの並びが変わった場合はネイティブのリストを再読み込みし、IDから選択位置を復元します。このAPIはアニメーション付き差分更新を提供しません。スクロール位置の完全な維持や、取り除いた項目のローカルStateの復元も保証しません。

絞り込みで見えなくなった選択IDはBindingに保持します。複数選択の操作では、表示外のIDを保持したまま表示中の選択だけを変更します。単一選択のユーザー操作は、表示外の選択も置き換えます。永久に削除したIDの選択解除はアプリ側で行います。

テーブルは単一列、コレクションは単一セクションです。複数列・アウトライン・独自データソースには `AppKitCoordinatedView` を使ってください。データ初期化子ではブリッジがdelegate/dataSourceを所有します。コレクションのlayoutファクトリは生成時だけ呼ばれ、変更にはビューの `.id` などで新しい表示インスタンスを作ります。

## Environmentの反映範囲

| 設定 | AppKitの動作 |
|---|---|
| `disabled` | NSControlのisEnabled、NSTextViewの編集・選択、リストのユーザー選択へ反映 |
| `scrollDisabled` | 専用リスト・TextView・AppKitManagedScrollViewのホイールとスクローラ操作へ反映。プログラムによるスクロールは可能 |
| `lineLimit` | 編集不可のNSTextFieldへ反映。明示的なnumberOfLinesを優先し、nilは無制限 |
| `locale` | ローカライズするタイトルとプレースホルダー、日付ピッカーへ反映 |
| `calendar` / `timeZone` | 日付ピッカーへ反映 |
| 行のEnvironment | NSHostingView内のSwiftUIコンテンツへ渡す |

任意のNSViewや、通常のNSScrollViewのイベントを一律に遮断する機能ではありません。標準の `font` や `foregroundStyle` をネイティブプロパティへ変換することもありません。未対応の設定は `configureAppKit` か、Contextを受け取る `update` で指定します。

`refreshable` のプル操作への接続、UIKit版のObservableモデルAPI、NSWindow / NSWindowControllerの表示管理は含みません。別ウィンドウはSwiftUIのWindow / WindowGroupなど、所有と表示のライフサイクルに合うAPIで管理します。

## 検証

CIはXcode 16 / 27で `swift build --target AppKitSwiftUI` と `swift test` を実行します。テストはネイティブのNSHostingViewとNSWindowを使い、target/actionの更新と復元、Binding、IME、Environment、選択の復元、ローカライズを検証します。macOS 13は最低デプロイメントターゲットです。ランナー上で実行した結果はmacOS 13実機の動作検証を意味しません。

参考: [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)、[SwiftUIとAppKitの統合](https://developer.apple.com/videos/play/wwdc2022/10075/)。

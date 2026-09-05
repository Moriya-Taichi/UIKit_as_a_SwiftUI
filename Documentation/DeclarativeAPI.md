# 宣言的APIへの移行

既存の初期化子、`configure:`、`setting`、Observableモデルは引き続き利用できます。新しいAPIは、内容と状態を初期化子へ渡し、UIKit固有の設定を修飾子で指定するための追加です。

## 設定を修飾子に移す

```swift
// 既存API
UIKitTextField("名前", text: $name, configure: {
    $0.borderStyle = .roundedRect
    $0.clearButtonMode = .whileEditing
})

// 新API
UIKitTextField(verbatim: "名前", text: $name)
    .textFieldBorderStyle(.roundedRect)
    .textFieldClearButtonMode(.whileEditing)
```

個別の修飾子がない設定には`configureUIKit`を使います。このメソッドは設定を記述順に追加し、SwiftUIの更新ごとに実行します。初回だけの生成・登録処理には、汎用ブリッジの`make`を使ってください。

```swift
UIKitView(make: UILabel.init)
    .text(name)
    .configureUIKit {
        $0.font = .preferredFont(forTextStyle: .headline)
        $0.adjustsFontForContentSizeCategory = true
    }
    .measuringWithAutoLayout()
    .lineLimit(2)
```

`configureUIKit`やクラス固有の修飾子は具体型を保ったまま`Self`を返します。`padding`や`frame`などで一般的なSwiftUIビューに変換する前に指定してください。`onUIKitSubmit`と標準の環境修飾子は、一般的なSwiftUI修飾子の後や親ビューにも指定できます。

| 設定 | 優先順位・動作 |
|---|---|
| `disabled` | SwiftUIの環境値を優先する。子の`disabled(true)`も維持する |
| `scrollDisabled` | SwiftUIの環境値を優先する |
| `lineLimit` | ラベルの初期設定として適用し、`nil`は無制限。明示的な`numberOfLines`やUIKit設定を優先する |
| `configureUIKit` | 既存の`configure:`の後に、追加した順番で実行する |
| `onUIKitSubmit` | 親から子の順に通知。モデルイベントと既存の`onSubmit:`引数の動作も維持する |

`UIControl.isEnabled`と`UIScrollView.isScrollEnabled`はEnvironmentが管理します。`configureUIKit`でこれらの値を書いても更新の最後に上書きするため、`disabled` / `scrollDisabled`へ移行してください。SwiftUI自身がUIKitプロパティを上書きするOSでも同じ優先順位になります。

ラベルは、行数を指定しなければSwiftUIと同じく無制限になります。従来の`UILabel`の初期値である1行に固定したい場合は、`.numberOfLines(1)`を指定してください。`lineLimit(_:reservesSpace:)`などが持つ空間予約までは再現しません。

`uiKitKeyboardType`、`uiKitTextContentType`、`uiKitReturnKeyType`はUITextField/UITextViewを包むブリッジに適用できます。標準の同名相当の修飾子を上書きしないため、親の標準`keyboardType`や`onSubmit`との暗黙の連携はありません。

## 選択を安定した値で表す

セグメントでは表示インデックスをアプリの状態として持つ必要がなくなります。

```swift
enum Filter: String, CaseIterable {
    case all, favorites
}

@State var filter: Filter = .all

UIKitSegmentedControl(Filter.allCases, selection: $filter) { $0.rawValue }
```

`Binding<Filter?>`も受け取れます。選択値がデータに含まれなければ何も選択せず、アプリ側の値を上書きしません。値は全セグメントで一意にしてください。既存の`[String]`と`Binding<Int>`を受け取る初期化子も利用できます。

## リストの表示データとIDを分ける

既存の`UIKitListModel`は項目の値全体を識別子として扱います。名前などの表示内容を変更しても同じ行として扱いたい場合は、データ初期化子へ移行します。

```swift
struct User: Identifiable {
    let id: Int
    var name: String
}

@State var users = [User(id: 1, name: "Alice")]
@State var selectedIDs: Set<User.ID> = []

UIKitTableView(users, selection: $selectedIDs) { user in
    Label(user.name, systemImage: "person")
}
```

`Identifiable`でない型には`id: \.userID`などのキーパスを渡します。単一選択は`Binding<ID?>`、複数選択は`Binding<Set<ID>>`です。表示データは`Hashable`である必要がなく、識別子だけに`Hashable & Sendable`を要求します。

`UIKitCollectionView`にも同じデータを渡せます。

```swift
UIKitCollectionView(
    users,
    selection: $selectedIDs,
    layout: {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 180, height: 60)
        return layout
    }
) { user in
    Text(user.name)
}
```

同じIDの表示内容・親のEnvironmentが変わると既存セルを再設定します。SwiftUI行のIDも指定するため、異なる項目へのセル再利用時に行の状態を混同しません。項目を一度削除した後や画面外へ再利用された後まで、行のローカル`State`が保存される保証はありません。必要な状態はIDをキーにしてアプリ側で保持してください。

表示中のIDと選択Bindingの共通部分が、実際の選択になります。フィルタリングやページ切り替えによって表示しなくなったIDはBindingに残り、再表示で選択を復元します。永久に削除した項目のIDは、呼び出し側でBindingからも削除してください。

データ初期化子は単一セクション用です。複数セクションやUIKitのセルクラスを直接扱う場合は既存のモデル初期化子を使います。テーブルの`style`とコレクションの`layout`ファクトリは生成時に使われるため、切り替える場合はSwiftUIの`id`などで新しいビューを生成してください。

## モデルの送信通知を受け取る

```swift
UIKitTextField(localized: "名前", model: model)
    .onUIKitSubmit {
        save(model.text)
    }
```

`model.events`の購読Taskと併用できます。この修飾子はストリームを購読せず、UIKitの通知を直接受け取ります。`UIKitTextFieldDeciding.shouldReturn`で送信を拒否した場合は、修飾子にもモデルの送信イベントにも通知しません。`UIKitSearchBar`の検索ボタンにも対応しています。複数行の`UIKitTextView`では改行を送信とは解釈しません。

標準の`onSubmit`と`submitScope`とは独立しています。既存のBinding初期化子の`onSubmit:`も指定した場合、そのクロージャと修飾子の両方を呼びます。

## 型とローカライズ

| 用途 | 新しい指定 |
|---|---|
| Doubleのスライダー | `UIKitSlider(value: $doubleValue)` |
| ローカライズする入力・ボタン | `UIKitTextField(localized: resource, text: ...)` / `UIKitButton(localized: resource) { ... }` |
| そのまま表示する入力・ボタン | `verbatim:` |
| 検索欄のプレースホルダー | `localizedPrompt:` / `verbatimPrompt:` |
| ローカライズするセグメント | `localizedTitle:` |
| ローカライズするラベル | `UIKitView(make: UILabel.init).text(localized: resource)` |
| ラベル付き日付ピッカー | `UIKitDatePicker("誕生日", selection: ..., displayedComponents: [.date])` |
| UIKitの日付ピッカーモード | `UIKitDatePicker(selection: ..., mode: .time)` |

ローカライズ入力は`LocalizedStringResource`で受け取り、そのバンドルとキーを保ったまま、SwiftUIの`locale`で解決します。既存の`String`引数を自動的に翻訳キーへ変更することはありません。

日付ピッカーの既存のラベルなし`displayedComponents:`引数は、ソース互換性のため`UIDatePicker.Mode`のままです。新しいラベル付き初期化子は`DatePickerComponents`を使用します。これにより、既存の`displayedComponents: .date`も曖昧になりません。

SliderのUIKit内部表現は`Float`です。Doubleを表示するだけでは元のBindingを丸めて書き戻しませんが、ユーザー操作で受け取る値はFloatの精度になります。

## 更新処理と破棄

リストと、汎用ブリッジで包んだ`UIScrollView`には標準の`refreshable`を付けられます。更新中の重複要求は無視し、アクションが戻るとインジケータを終了します。修飾子の解除やビュー破棄でTaskをキャンセルしますが、アクション側にも協調的なキャンセルへの対応が必要です。

ブリッジが一時的に置き換えた外部の`UIRefreshControl`は、ブリッジのコントロールがまだ装着されている場合に復元します。デリゲート、データソース、UIActionなどの所有は引き続きコーディネータが担当します。

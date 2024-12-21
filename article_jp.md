本記事ではTerraformのfor_eachの堅牢な使い方について説明します。

for_eachは繰り返しのリソース作成に非常に強力な仕組みである一方、キーが既知の値(known value)である必要があります。
-targetでエラーを回避することもできますが、本質的な解決ではなく、コードの変更容易性などを下げるものに理ます。
エラーが発生する仕組みを理解し、解消するコードを考えることが重要です。本記事はfor_eachの基本的な使い方を説明し、その上で重要な制約であるキーが既知の値(known value)であること
とを詳しく説明します。それを踏まえて堅牢なfor_eachの使い方のガイドを示します。また、そのガイドを満たさない場合どのようなときにfor_eachが堅牢でなくなるかを解説します。
最後にfor_each利用時に重要な知識としてtosetとfor_eachの連鎖について解説します。

- for_eachの基本的な使い方
  - 例のコード交えた簡易的な説明
  - 公式ガイドでも控えめな利用が推奨されている。あまり凝ったことをしない方が良いのが前提。
- 重要な制約
  - keyがknown valueである必要がある
  - known valueとは
- for_each利用のガイドライン
  - unknownな値をキーに利用しない
    - OKとNGの例のコード
  - キーは可能な限り一貫性が高く、変更頻度が低いものにする
    - OKとNGの例のコード
- for_eachが堅牢でなくなる時
  - キーにunknown valueが利用された時
    - お馴染みのエラーが出る。これを-targetで解決するのはワークアラウンドだと考えた方が良いです。難しいのが、既存リソースがあるとknown valueとなりキーにしてもエラーにならないことです。同じTerraformのコードを使って新規で作成する場合エラーが発生します。私の調べた限りlintなどもないため、現状は意識するしかないという状況です。
    - 自動化の妨げになったり、新規作成時に必ず同様のエラーが出るため、再利用性にも影響します。
    - 参照するコードを変更した場合に同様のエラーが出るため、エラー発生の原因が参照先にも伝搬します。そのためコード全体として変更容易性が下がります。（例のコードも書く）
  - キーが将来的に一意でなく、頻繁な変更が必要な時
    - キーが変わると再作成になります。再作成が容易なリソースではない場合stateの移行作業などが発生してしまいます。
    - 例えばvpc subnetを作るときに最初は2個しかいらなくて、AZを含めたsubnet_1a、subnet_1bをキーにするとします。すると他の用途でsubnetを増やしたい場合に同じキーを使えません。キーの変更は再作成になるので将来的に変わりづらい値かどうかは考慮して作ると良いでしょう。
- for_each利用時に重要な知識
  - tosetの挙動
    - setとは
    - for_eachはキーが一意である必要があるためmapとsetをinputにできる
    - setを利用した場合、キーとバリューが同じになるためバリューも含めて上記ガイドラインを満たす必要がある
  - for_eachは連鎖できる
    - よくやってしまいそうなのが、他のfor_eachで作成したリソースの属性をforでリストにしてtosetに渡すとか
    - for_eachの関係が1:1なら動的な作成を連鎖できる。個人的にはfor_eachの連鎖以上に複雑な動的な作成をしない方が良いと思う。それ以上は愚直書いた方が良い。
- まとめ
    


----
以下は上記の内容になりそうなことをメモしたもの。これを参考にかく。

キーの一貫性とソース管理：
for_each のソースとなるマップ・セットは可能な限り一貫性が高く、変更頻度が低いものにしましょう。
設定ファイルの refactoring 時やデータを外部ソースから取得する場合、キーが変わらないよう設計することで、Terraform 実行時の差分が安定します。

以下のエラーに遭遇した場合は、本記事で解説した「堅牢な for_each の使い方」を確認し、for_each 利用時のキー定義や unknown 値回避のベストプラクティスを再考することをお勧めします。

vbnet
コードをコピーする
│ The "for_each" set includes values derived from resource attributes that cannot be determined until apply, and so Terraform cannot
│ determine the full set of keys that will identify the instances of this resource.
│
│ When working with unknown values in for_each, it's better to use a map value where the keys are defined statically in your
│ configuration and where only the values contain apply-time results.
│
│ Alternatively, you could use the -target planning option to first apply only the resources that the for_each value depends on, and
│ then apply a second time to fully converge.
このエラーは、for_each のキーとして unknown な値（apply時でないと確定しないリソース属性など）を用いている場合に発生します。記事で紹介したガイドラインを参考に、静的かつ確定的なキーの利用や for_each のチェーニング設計、map の適切な活用を検討し、Terraform コードを安定化させてください。


ガイドライン
キーは静的かつ一意な値を用いる

解説:
for_each に指定するコレクション（mapやset）のキーは、そのリソースを特定する “ID” の役割を果たします。
将来にわたって変更されにくく、plan 時点で確定している（unknown でない）値を利用してください。
これにより、Terraform がリソースを正しく追跡でき、不要なリソースの再作成を防ぐことができます。
data ソースや未作成リソース由来の unknown な値をキーに使わない

解説:
data リソースや、まだ作成されていないリソース属性は plan 時点で値が確定せず unknown となる場合があります。
unknown な値をキーにすると、plan・apply のたびに差分が生じ、Terraform がリソース状態を適切に管理できなくなります。
未作成リソースの属性を参照したい場合は、for_each を分段階でチェーンする（最初に生成したリソースの出力を次の for_each の入力とする）など、生成順序を明確にする設計を検討してください。
将来変わりにくい「代理キー」を採用する


本ガイドラインでは、静的・一意なキーの利用, unknown 値を避ける設計, 型変換の理解, -target 常用回避 などにより、for_each 利用時の堅牢性・信頼性を高める手法を提案しています。これらの原則に従うことで、Terraform コードはメンテナブルかつトラブルを回避しやすい状態となり、安定したインフラ運用に寄与します。


------
以下は検証時のコード

# locals {
#   subnet_list = [
#     { "name" = "subnet1", "cidr" = "10.0.1.0/24" },
#     { "name" = "subnet2", "cidr" = "10.0.2.0/24" },
#     { "name" = "subnet3", "cidr" = "10.0.3.0/24" },
#   ]
# }

# resource "terraform_data" "subnet" {
#   for_each = { for subnet in local.subnet_list : subnet.name => subnet }
#   input = {
#     cidr_block  = each.value.cidr
#     tags = {
#         Name = each.key
#     }
#   }
# }

locals {
  subnets = {
    // keyはよく設計しておいた方が良い。あとで変わると関連するリソースが作り直しになる
    // keyを意識した作りをするためにmapを使った方が良い。listで作ってfor_eachの前にmapやsetに変換するのもできるがどうしてもkeyを意識しなくなってしまう。
    // 文字列や数値などの単純なリストを使いたい時はtosetでいいかも。オブジェクト扱うならtosetしない方が良さそう
    subnet1 = { "cidr" = "10.0.1.0/24" },
    subnet2 = { "cidr" = "10.0.2.0/24" },
    subnet3 = { "cidr" = "10.0.3.0/24" },
  }
}

resource "terraform_data" "subnet" {
  for_each = local.subnets
  input = {
    cidr_block = each.value.cidr
    tags = {
      Name = each.key
    }
  }
}
locals {
  # unknown_values_map = {
  #   subnet1 = terraform_data.subnet["subnet1"].id
  #   subnet2 = terraform_data.subnet["subnet2"].id
  #   subnet3 = terraform_data.subnet["subnet3"].id
  # }
  // valueがunknownでもいける
  unknown_values_map = {
    for i, s in local.subnets : i => terraform_data.subnet["subnet1"].id
  }
}

resource "terraform_data" "subnet_flow_log" {
  # error
  # for_each = toset([for s in terraform_data.subnet : s.id]) # keyがunknownになってしまう
  for_each = local.unknown_values_map
  input = {
    subnet_id = each.value
  }
  # for_each = terraform_data.subnet
  # input = {
  #   subnet_id = each.value.id
  # }
}
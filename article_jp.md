Terraformの`for_each`を利用して、以下のエラーに遭遇したことがある人は多いのではないでしょうか。

```
The "for_each" set includes values derived from resource attributes that cannot be determined until apply, and so Terraform cannot determine the full set of keys that will identify the instances of this resource.

When working with unknown values in for_each, it's better to use a map value where the keys are defined statically in your configuration and where only the values contain apply-time results.

Alternatively, you could use the -target planning option to first apply only the resources that the for_each value depends on, and then apply a second time to fully converge.
```

このエラーを回避する方法として、`-target`で先に依存するリソースのみをapplyする、という方法があります。
しかし、この方法では長期的には負債を抱え込む可能性があります。
本記事では、上記エラーの理由が理解できるような`for_each`の解説と共に、堅牢に`for_each`を活用するためのポイントを紹介します。

---

[:contents]

---

# `for_each`を堅牢に活用するポイント

1. `for_each`のキーは原則`known value`(plan時点で確定した値)になるようにし、`-target`による解決に頼らない
2. キーは一貫性が高く変更されにくいものを選ぶ

上記が本記事のコアです。以降は上記を理解するための説明になります。

まず`for_each`の基本と重要な制約について説明していきます。その後、上記のポイントを満たさない場合どのようなことが起きるかを説明し、理解を深めます。

# for_eachの基本

`for_each`はTerraform記述内で同種のリソースを繰り返し作成する際に用いる機能です。`count`と似た役割を果たしますが、`for_each`は、リソースに一意なキーを割り当てることで、リソースの増減時などに不要な再作成を抑える効果が期待できます。一方で、キーの扱いには制約があり、そこを正しく理解しないとエラーに直面しやすくなります。

<details>
  <summary>for_eachのコード例</summary>

ダミーの resource として[terraform_data](https://developer.hashicorp.com/terraform/language/resources/terraform-data)を用いて簡単なコードを書いてみます。

```hcl
locals {
  subnets = {
    subnet1 = { "cidr" = "10.0.1.0/24" },
    subnet2 = { "cidr" = "10.0.2.0/24" },
    subnet3 = { "cidr" = "10.0.3.0/24" },
  }
}

resource "terraform_data" "subnets" {
  for_each = local.subnets
  input = {
    cidr_block = each.value.cidr
    tags = {
      Name = each.key
    }
  }
}
```

plan結果は以下のようになります。

```hcl
Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # terraform_data.subnets["subnet1"] will be created
  + resource "terraform_data" "subnets" {
      + id     = (known after apply)
      + input  = {
          + cidr_block = "10.0.1.0/24"
          + tags       = {
              + Name = "subnet1"
            }
        }
      + output = (known after apply)
    }

  # terraform_data.subnets["subnet2"] will be created
  + resource "terraform_data" "subnets" {
      + id     = (known after apply)
      + input  = {
          + cidr_block = "10.0.2.0/24"
          + tags       = {
              + Name = "subnet2"
            }
        }
      + output = (known after apply)
    }

  # terraform_data.subnets["subnet3"] will be created
  + resource "terraform_data" "subnets" {
      + id     = (known after apply)
      + input  = {
          + cidr_block = "10.0.3.0/24"
          + tags       = {
              + Name = "subnet3"
            }
        }
      + output = (known after apply)
    }

Plan: 3 to add, 0 to change, 0 to destroy.
```

このように、`for_each`には`map`や`set`など、キーが一意になるコレクションを渡します。`each.key`でキー名(`subnet1`、`subnet2`、`subnet3`)を、`each.value`でその値(`cidr`など)を参照できます。キーは作成されるTerraformのリソース名にも利用されます。

</details>

## 公式ドキュメントでは「控えめな利用」を推奨

> Use count and for_each sparingly.

[公式のスタイルガイド](https://developer.hashicorp.com/terraform/language/style)では、`for_each`や`count`の控えめな利用が推奨されています。過度に利用せず、可能な限りシンプルな形で記述するのが良いでしょう。複雑な依存関係を内包した動的なリソース生成は、運用フェーズで問題を引き起こしやすいです。

## 重要な制約：キーは`known value`でなければいけない

`for_each`を利用する上で非常に重要な制約は、「`for_each`に渡す`map`のキーがplan時点で確定している`known value`でなければならない」という点です。`for_each`の入力が`set(string)`の場合はすべての値が`known value`である必要があります。`unknown value`を指定してしまうと冒頭のエラーが発生します。

なお、`map`や`set`などループで扱う型の理解も重要となります。もし曖昧な方は[Terraformの型とループ処理 for_each = { for } について理解する](https://zenn.dev/kasa/articles/8fe998e04cb916)をぜひ読んでみてください。

<details>
  <summary>for_eachのキーにunknown valueを利用してエラーになる例</summary>

```hcl
resource "terraform_data" "subnets" {
  for_each = toset(["a", "b"])
  input = {
    key   = each.key
    value = each.value
  }
}
resource "terraform_data" "subnet_flow_log" {
  # 初期作成時にキーが unknown value になってしまうのでエラーになる
  for_each = toset([for s in terraform_data.subnets : s.id])
  input = {
    subnet_id = each.value.id
  }
}
```

上記のコードをplanすると冒頭のエラーが発生します。

</details>

# for_eachが堅牢でなくなる時

ここまでで`for_each`の基本と、重要な制約について説明ができました。冒頭のポイントを再掲します。

1. `for_each`のキーは原則`known value`(plan時点で確定した値)になるようにし、`-target`による解決に頼らない
2. キーは一貫性が高く変更されにくいものを選ぶ

ではこれらを満たさない場合どのようなことが起きるのでしょうか。それを説明していきます。

## キーに`unknown value`を利用した時

キーが`unknown value`だと、冒頭のエラーが出ることがあります。

```
│ The "for_each" set includes values derived from resource attributes that cannot be determined until apply, and so Terraform cannot determine the full set of keys that will identify the instances of
│ this resource.
│ 
│ When working with unknown values in for_each, it's better to use a map value where the keys are defined statically in your configuration and where only the values contain apply-time results.
│ 
│ Alternatively, you could use the -target planning option to first apply only the resources that the for_each value depends on, and then apply a second time to fully converge.
```

このエラーは「`for_each`のキーには`known value`を指定しよう。`unknown value`を扱いたいなら`map`を利用するといいよ。あるいは`-target`で収束させることもできます」と書かれています。

`-target`を使って段階的に適用すれば回避可能な場合がありますが、本質的な解決ではありません。運用自動化の足枷になったり、コードの変更容易性が低下します。

例えば共有モジュールを変更して各利用先で自動planをするとエラーで落ちます。自動applyによる運用自動化の足枷にもなります。共有モジュールの利用先が2,3個であれば良いですが、それが30個と増えていくと各環境での`-target`も大変な作業になっていきます。

また、このエラーは参照先にも伝播します。

[f:id:paper2parasol:20241227170401p:plain]

例えば`subnet_flow_log`が`subets`リソースの`id`など`unknown value`になり得る値を参照している場合に、`terraform apply -target=subnets`で一時的にエラーを回避したとしても、その後subnetを追加してapplyしようとすると同じエラーが発生します。

<details>
  <summary>subnetを追加すると再度エラーになる例</summary>

```hcl
locals {
  subnets = {
    subnet1 = { "cidr" = "10.0.1.0/24" },
    subnet2 = { "cidr" = "10.0.2.0/24" },
    subnet3 = { "cidr" = "10.0.3.0/24" },
#    subnet4 = { "cidr" = "10.0.4.0/24" },  <- -targetで収束した後に追加しようとするとエラーになる
  }
}

resource "terraform_data" "subnets" {
  for_each = local.subnets
  input = {
    cidr_block = each.value.cidr
    tags = {
      Name = each.key
    }
  }
}

resource "terraform_data" "subnet_flow_log" {
  for_each = toset([for s in terraform_data.subnets : s.id])
  input = {
    subnet_id = each.value
  }
}
```
</details>

業務で活用するコードは長期間の運用を想定し、変更時にエラーがでやすいコードは書かない方が良いです。そのため、`-target`で解決するのではなく`unkown value`をキーにしない工夫を考えた方が良いでしょう。

その工夫の一つとして`for_each`の[連鎖(chaining)](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each#chaining-for_each-between-resources)があります。

<details>
  <summary>for_eachの連鎖を利用した例</summary>

以下はキーに`unknown value`を使わず連鎖させる一例です。

```hcl
locals {
  subnets = {
    subnet1 = { "cidr" = "10.0.1.0/24" },
    subnet2 = { "cidr" = "10.0.2.0/24" },
    subnet3 = { "cidr" = "10.0.3.0/24" },
  }
}

resource "terraform_data" "subnets" {
  for_each = local.subnets
  input = {
    cidr_block = each.value.cidr
    tags = {
      Name = each.key
    }
  }
}

resource "terraform_data" "subnet_flow_log" {
  # for_eachで作成したリソースを直接渡す
  for_each = terraform_data.subnets
  input = {
    subnet_id = each.value.id
  }
}
```
</details>


一方で、一度applyが済んだ既存リソースを参照する場合、そのタイミングでは参照する値が`known value`となっているため、気付かずにそのようなコードを書いてしまうこともあります。

環境複製時や依存先の変更時に初めてエラーに遭遇するケースもあります。lintなどの自動チェックができない状況では`for_each`を正しく理解し、開発者が常にこの問題を意識する必要があります。

## キーが将来的に一意でなくなったり、変更が必要な時

本記事の大半は`unknown value`を`for_each`のキーにしないことの解説になっています。しかし、キー設計も堅牢性を保つ上で非常に重要なポイントです。  

キーが変更されると、Terraformはリソースが別物と判断して再作成します。これが気軽に再作成できるリソースでない場合、大量のステート移行が必要となることもあり、変更コストが高くなります。設計段階でキーが変わる可能性を検討し、なるべく変わらず一貫性を保ち続けるキーを設計することが重要です。  

<details>
  <summary>キー変更時における影響の例</summary>

例えばサブネットは良い例です。状況によって命名規則をどのようにするか検討する必要があります。

やや極端な例ですが変わりやすいキーとして、アベイラビリティーゾーンをベースにキーを作成する場合を考えてみます。

```hcl
locals {
  subnets = {
    subnet1 = { "cidr" = "10.0.1.0/24" },
    subnet2 = { "cidr" = "10.0.2.0/24" },
    subnet3 = { "cidr" = "10.0.3.0/24" },
  }
}

resource "terraform_data" "subnets" {
  for_each = local.subnets
  input = {
    cidr_block = each.value.cidr
    tags = {
      Name = each.key
    }
  }
}
```

このコードは問題なく`apply`できます。しかし、後からプライベートサブネットを追加する要件が出た場合、以下のように変更することが考えられます。

```diff
 locals {
   subnets = {
-    subnet_1a = { "cidr" = "10.0.1.0/24", "az" : "ap-northeast-1a" },
-    subnet_1c = { "cidr" = "10.0.2.0/24", "az" : "ap-northeast-1c" },
-    subnet_1d = { "cidr" = "10.0.3.0/24", "az" : "ap-northeast-1d" },
+    subnet_1a_public  = { "cidr" = "10.0.1.0/24", "az" : "ap-northeast-1a" },
+    subnet_1c_public  = { "cidr" = "10.0.2.0/24", "az" : "ap-northeast-1c" },
+    subnet_1d_public  = { "cidr" = "10.0.3.0/24", "az" : "ap-northeast-1d" },
+    subnet_1a_private = { "cidr" = "10.0.11.0/24", "az" : "ap-northeast-1a" },
+    subnet_1c_private = { "cidr" = "10.0.12.0/24", "az" : "ap-northeast-1c" },
+    subnet_1d_private = { "cidr" = "10.0.13.0/24", "az" : "ap-northeast-1d" },
   }
 }
```

上記の変更により、以下のように既存のサブネットが削除され、新しいサブネットが再作成されます。

```hcl
  # terraform_data.subnets["subnet_1a"] will be destroyed
  # (because key ["subnet_1a"] is not in for_each map)
  - resource "terraform_data" "subnets" {
      - id     = "7ec886b9-9713-84f6-765b-2bc71d01a667" -> null
      - input  = {
          - availability_zone = "ap-northeast-1a"
          - cidr_block        = "10.0.1.0/24"
          - tags              = {
              - Name = "subnet_1a"
            }
        } -> null
    }

  # terraform_data.subnets["subnet_1a_public"] will be created
  + resource "terraform_data" "subnets" {
      + id     = (known after apply)
      + input  = {
          + availability_zone = "ap-northeast-1a"
          + cidr_block        = "10.0.1.0/24"
          + tags              = {
              + Name = "subnet_1a_public"
            }
        }
    }
```

既存のサブネットを削除できない場合ステートの移行作業を行う必要があります。関連するリソースが多いとこれが結構面倒な作業になります。

このように、キーの設計は`for_each`を堅牢に活用するための重要な要素です。長期運用を想定し、キーの一貫性と変更耐性を考慮した設計が求められます。

</details>

# まとめ

- `for_each`のキーは原則`known value`(plan時点で確定した値)になるようにし、`-target`による解決に頼らない。  
- キーは一貫性が高く変更されにくいものを選ぶ。

という2点が重要です。`-target`を常用するのは本質的な解決ではなく、運用を複雑化させます。`for_each`を正しく理解し、堅牢なTerraformコードを維持していきましょう。

# (おまけ）`for_each`と`set`

`for_each`を扱う上で`set`の理解は重要です。`set(string)`の値は`for_each`のキーとして直接利用されるため、`known value`である必要があります。

まず以下の簡単な例を見てみます。

```hcl
resource "terraform_data" "subnets" {
  for_each = toset(["a", "b"])
  input = {
    key   = each.key
    value = each.value
  }
}
```

これをplanすると以下の結果になります。リソースのキーを確認してください。

```hcl
Terraform will perform the following actions:

  # terraform_data.subnets["a"] will be created
  + resource "terraform_data" "subnets" {
      + id     = (known after apply)
      + input  = {
          + key   = "a"
          + value = "a"
        }
      + output = (known after apply)
    }

  # terraform_data.subnets["b"] will be created
  + resource "terraform_data" "subnets" {
      + id     = (known after apply)
      + input  = {
          + key   = "b"
          + value = "b"
        }
      + output = (known after apply)
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

`for_each`に渡された`set(string)`はキーと値両方に利用されていることがわかります。そのため、リストに`unknown value`を含めて`toset`関数で`set`を作るとエラーになります。

`toset`関数を利用する場合は値も`unkown value`にならないように気をつけましょう。
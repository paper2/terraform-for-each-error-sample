
// example-1
# locals {
#   subnets = {
#     subnet1 = { "cidr" = "10.0.1.0/24" },
#     subnet2 = { "cidr" = "10.0.2.0/24" },
#     subnet3 = { "cidr" = "10.0.3.0/24" },
#   }
# }

# resource "terraform_data" "subnets" {
#   for_each = local.subnets
#   input = {
#     cidr_block = each.value.cidr
#     tags = {
#       Name = each.key
#     }
#   }
# }


// example-2
# locals {
#   subnets = {
#     subnet1 = { "cidr" = "10.0.1.0/24" },
#     subnet2 = { "cidr" = "10.0.2.0/24" },
#     subnet3 = { "cidr" = "10.0.3.0/24" },
#   }
# }

# resource "terraform_data" "subnets" {
#   for_each = local.subnets
#   input = {
#     cidr_block = each.value.cidr
#     tags = {
#       Name = each.key
#     }
#   }
# }

# resource "terraform_data" "subnet_flow_log" {
#   # 初期作成時にキーが unknown value になってしまうのでエラーになる
#   for_each = toset([for s in terraform_data.subnets : s.id])
#   input = {
#     subnet_id = each.value
#   }
# }

// example-3
# resource "terraform_data" "subnets" {
#   for_each = toset(["a", "b"])
#   input = {
#     key   = each.key
#     value = each.value
#   }
# }

// example-4

# resource "terraform_data" "subnet_flow_log" {
#   # 初期作成時にキーが unknown value になってしまうのでエラーになる
#   for_each = toset([for s in terraform_data.subnets : s.id])
#   input = {
#     subnet_id = each.value.id
#   }
# }

// example chaining
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
  for_each = terraform_data.subnets
  input = {
    subnet_id = each.value.id
  }
}

// example-5
# locals {
#   subnets = {
#     subnet1 = { "cidr" = "10.0.1.0/24" },
#     subnet2 = { "cidr" = "10.0.2.0/24" },
#     subnet3 = { "cidr" = "10.0.3.0/24" },
#   }
# }

# resource "terraform_data" "subnets" {
#   for_each = local.subnets
#   input = {
#     cidr_block = each.value.cidr
#     tags = {
#       Name = each.key
#     }
#   }
# }



// この記事良かった。for_eachは便利だけど再作成などのリスクを伴うみたいな説明も上手い。
// https://spacelift.io/blog/terraform-for-each#terraform-for-each-indexing-issues


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


// valueがunknownでもいけるか調査
# locals {
#   # unknown_values_map = {
#   #   subnet1 = terraform_data.subnet["subnet1"].id
#   #   subnet2 = terraform_data.subnet["subnet2"].id
#   #   subnet3 = terraform_data.subnet["subnet3"].id
#   # }
#   unknown_values_map = {
#     for i, s in local.subnets : i => terraform_data.subnet["subnet1"].id
#   }
# }

# resource "terraform_data" "subnet_flow_log" {
#   # error
#   # for_each = toset([for s in terraform_data.subnet : s.id]) # keyがunknownになってしまう

#   # valueがunknownでもいけるか調査
#   # for_each = local.unknown_values_map
#   # input = {
#   #   subnet_id = each.value
#   # }

#   for_each = terraform_data.subnet
#   input = {
#     subnet_id = each.value.id
#   }
# }

// 基本的にkeyが動的に

// limitation
// https://developer.hashicorp.com/terraform/language/meta-arguments/for_each#limitations-on-values-used-in-for_each

// chaiging
// https://developer.hashicorp.com/terraform/language/meta-arguments/for_each#chaining-for_each-between-resources



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
# resource "terraform_data" "subnet_flow_log" {
#   # 初期作成時にキーが unknown value になってしまうのでエラーになる
#   for_each = toset([for s in terraform_data.subnets : s.id])
#   input = {
#     subnet_id = each.value.id
#   }
# }

// example-4
# locals {
#   subnets = {
#     subnet1 = { "cidr" = "10.0.1.0/24" },
#     subnet2 = { "cidr" = "10.0.2.0/24" },
#     subnet3 = { "cidr" = "10.0.3.0/24" },
#     #    subnet4 = { "cidr" = "10.0.4.0/24" },  <- -targetで収束した後に追加しようとするとエラーになる
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
#   for_each = toset([for s in terraform_data.subnets : s.id])
#   input = {
#     subnet_id = each.value
#   }
# }

// example chaining
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
#   # for_eachで作成したリソースを直接渡すことができる。
#   # キーは渡したリソースのキーと同じになる。(subnet1, subnet2, subnet3)
#   for_each = terraform_data.subnets
#   input = {
#     subnet_id = each.value.id
#   }
# }

// example-5
locals {
  subnets = {
    subnet_1a = { "cidr" = "10.0.1.0/24", "az" : "ap-northeast-1a" },
    subnet_1c = { "cidr" = "10.0.2.0/24", "az" : "ap-northeast-1c" },
    subnet_1d = { "cidr" = "10.0.3.0/24", "az" : "ap-northeast-1d" },
  }
}

resource "terraform_data" "subnets" {
  for_each = local.subnets
  input = {
    cidr_block        = each.value.cidr
    availability_zone = each.value.az
    tags = {
      Name = each.key
    }
  }
}

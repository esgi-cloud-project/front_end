resource "aws_dynamodb_table" "front_end_product_table" {
  name           = "Product"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "Id"

  attribute {
    name = "Id"
    type = "S"
  }
}
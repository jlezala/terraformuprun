terraform {
	backend "s3" {
		bucket = "terraform-uar-redpenguin101"
		region = "us-east-1"
		key = "terraform.tfstate"
		encrypt = true
	}
}


provider "aws" {
	region = "us-east-1"
}

resource "aws_s3_bucket" "terraform_state" {
	bucket = "terraform-uar-redpenguin101"

	versioning {
		enabled = true
	}

	lifecycle {
		prevent_destroy = true
	}
}

output "s3_bucket_arn" {
	value = "${aws_s3_bucket.terraform_state.arn}"
}

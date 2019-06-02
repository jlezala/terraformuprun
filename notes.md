# book outline

1. why terraform, infra as code, comparison of tools
2. installations, syntax, cli, simple deployment
3. terraform states, managing and locking, folder layout
4. reusable infra, terraform modules
5. tips and tricks, advanced syntax

https://github.com/brikis98/terraform-up-and-running-code

# Chapter 1: Why terraform?

software delivery. used to be a lot of hardware, config - ops. now devops. no wall tossing. snowflake servers: different configs. more bugs. reduce deployments. mess.

today: cloud, ops are software guys, writing infra code. less distinction between dev and ops - devops. practices for more efficient software delivery. deploy daily, or every commit. resilient self healing systems. automation, culture, measurement, sharing (CAMS). this book focuses on automation.

## infra as code (IAC)
code defines, deploys and updates your infra. all operations is software. 

types of tools: adhoc scripts, config mgmt tools, server templating tools, server provisioning tools

### adhoc scripts
_setup-webserver.sh_
no enforcement, get super messy if you're trying to manage a dozen servers like that.

### config mgmt tools
chef, puppet, ansible, saltstack. install and manage software on existing servers. has codeing conventions, idempotence (code that runs the same no matter how many times you run it). meant for large numbers of remote servers

### server templating tools
alternative to CMTs. docker, vagrant. create an image of a server, with snapshot of op system, files etc. then use something like ansible to deploy it.

vm model vs conatiner model. vm simulate the entire computer system. fully isolated, run the same on everything. lots of overhead. container emulates user space of operating system, isolated memory, processes, mount points, networking. isolation, but to a lesser degree. but much less overhead.

often you'll use a vagrant to run a vm on your dev computer, i.e. your laptop, but will use docker for prod and dev containers on servers. Usually you containerise individual applications. You might use packer to create an AMI (Amazon Machine Image) on a cluster of aws servers, the deploy docker containers to run applications.

immutable infrastructure. you don't CHANGE servers. you image it and spin up a new one.

### Server provisioning tools
terraform, cloudformation, openstack heat.
creating the servers themselves - as well as dbs, caches, load balancers, just about every aspect of your infra. 

## IAC benfits
easier to deliver software. self service - no sysadmin bottlenecks. faster, safer. code is documentation. version control. validation, autotesting. reuse.

## Terraform
single binary, `terraform`. makes api calls on _providers_ eg amazon. you create _configurations_ to tell it how to work. when changing infra, you change those files, test themm commit and run `terraform`.

## Why terraform?
IAC programs: tradeoffs.
* config mgmt vs. provisioning
* mutable vs. immutable infra (install in place vs. new server)
* procedural vs. declarative
* master vs. masterless (master pushes out updates to other servers)
* agent vs. agentless (chef client etc. runs in background and manages.

# Chapter 2: getting started
using aws.

terraform code is written in hashicorp config language, HCL. .tf files. declarative langugae.

in a tf file you'll have a 'provider' block, and one or more resource blocks

```tf
resource "PROVIDER_TYPE" "NAME" {
	[CONFIG ...]
}
```
see first_script for example

use `terraform plan` to see what terraform will do. then `terraform apply` to do it

if you were to add a name tag in the file, and run `plan` again it sould find the server (it tracks resources already created) and update it inplace.

now is a good time to vc. you should git your main.tf file

also gitignore `.terraform`, `*.tfstate`, and `*.tfstate.backup`

## simple web server
```sh
echo "Hello World" > index.html
nohup busybox httpd -f -p 8080 &
```

running on ports below 1024 requires admin - usually bad idea.

in real world our web server would be more complicated than this (think Django) and you'd use Packer to create a custom AMI with the webserver installed on it. here we'll just add the script into the .tf file, as the user_data parameter which is executed which aws will execute on starting. You'll use heredoc syntax, EOF for creating multiline strings.

you'll also need to create a security group to allow webtraffic (disallowed by default on EC2 instances), as another resource.

CIDR blocks are  concise way to specify IP ranges.

you'll also need to amend the aws_instance to use it. use interposlation syntax `${TYPE.NAME.ATTRIBUTE}` to refer to other resources in the file

you can graph the dependencies you're creating when interpolating with `terraform graph`

apply again - not this time you'll have to tear down the instance and spin it up again. You'll have to do this for most things that aren't changing tags. when the server is up you can go to the ip:port and see hello world.

examples here deploy into default vpc, and also default vpc subnets of the vpc. these are all public subnets, which for a proper app is a bad idea, only a few small servers with reverse proxies and load balancers should be in public subnets

## Deploy a configurable web server
to adhere to DRY principles you can define input variables. every bit on knowledge must have a single authoritative representaion in the system.

```tf
varible "NAME" {
	[CONFIG ...]
}
```

contain optional params:
* description
* default
* type - string list or map (i.e. dict)

```tf
variable "list example" {
	description = "an example of a list"
	type = "list"
	default = [1,2,3]
}
```

when you enter a var without a default you will be prompted for it when you run `plan` or `apply`, or you can specify a cl with `terraform plan -var server_port = "8000"`

you can reference with interpolation code: `"${var.VARIABLE_NAME}"`

You can also define output variables with

```tf
output "public_ip" {
	value = "${aws_instance.example.public_ip"
}
```

this will be printed when you apply, and you can also grab it with `terraform output public_ip`

## Cluster of WS
with Auto Scaling Group (ASG) to manage for you

use a "aws_launch_configuration" resource, replacing ths instance resource. syntax is nearly the same, just add a 'lifecycle' param - almost any resource has a lifecycle param available which dictates how it's created updated and destroyed.

we set `create_before_destroy` meaning tf will create a new ec2 instance, initialise is, and only then remove the old one.

the catch with `create_before_destroy` is that is needs to also be on every resource that depends on depends on what you've put it on. for us, our security group will also need to have it

now create the ASG with the "aws_autoscaling_group" resource. you'll need to specify the launch config to use, the min and max sizes.

Also AZs - this is account specific so use a data source to fetch your available ones. a data source is a piece of read only info fetched from the provider. you can then reference it with `${data.TYPE.NAME.ATTRIBUTE}`

next you want a load balancer to figure out which instance to hit, and when to spin up more instances. use the `aws_elb` resource. You'll need a listener. you'll also need a new sec group for your elb and add it to your elb resrouce.

last, add a health check block. HC checks up on instances and stops routing traffic to them if it detects something is wrong. the sec group will need to be configured to allow this

put in an output for the dns address of the elb, apply and try the address

tear down your stuff with `terraform destroy`

# Chapter 3 how to manage terraform state
how tf tracks the state of infra you've created with tf, or otherwise deployed on aws. impact on file layout, isolation and lcoking

## tf state
a tf state file records the info about what infra tf has created. JSON format. whenever you run terraform it looks in here for info about the resources, peeks at aws to find those rsources, and compares them to whats in your config file.

issues when have multiple people: all team needs to access. locking becomes an issue. its best practice to isolate your environments (test, staging, prod etc.)

putting state files into vc is a bad idea, from security and error POV

tf has built in support for remote state storage. there are a few options including s3. though s3 is eventually-consistent, shouldnt be an issue unless your team is very large.

set up an s3 bucket in a new _main.tf_, identify aws as provider, create an s3 bucket resource. give it 3 params, a bucket name, versioning (enabled), and a 'prevent_destroy' lifecycle.

prevent destroy will stop `terraform destroy` tearing it down.

you'll need to define a `backend` configuration in your `.tf` file. (note, per the book this was done with command line). You'll have to run `terraform init` to set it up, and check your bucket for the file.

When this config is set, terraform will always pull the state from s3 before running a command, and automatically push the state to s3 after running. add an output "s3_bucket_arn" to see it in action. when applied, go to the s3 bucket, make sure versioning is selected and you'll be able to see a new version.

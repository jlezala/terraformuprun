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

apply again

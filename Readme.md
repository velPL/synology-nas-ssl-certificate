# Synology NAS free SSL certificate installer for CloudFlare DNS provider for devices that are not exposed to the internet

## Version 0.1.0 (initial release, breaking changes to be expected ‼️)

This project allows you to streamline a process of obtaining a free ZeroSSL certificate for your Synology NAS without a need to expose your device to the internet. It utilizes [acme.sh official script](https://github.com/acmesh-official/acme.sh) together with a DNS challenge for domain ownership verification, which is currently not supported by Synology's DSM 7 (at least in version 7.3.2-86009). 

>‼️ Before running the installation script as root, which is required, ensure you read the script and understand fully what it is doing (asking your AI model of choice for help is also a good idea) - you should NEVER blindly run any scripts straight from internet, especially as root user ‼️

## Prerequisites
In order to be able to successfully install certificate helper scripts you need to ensure that:
1. You are running DSM 7.x on your NAS (please help testing that on older versions and provide your feedback in the issues section 🙏)
2. A domain managed by CloudFlare as provider
3. An `A` entry in DNS with a domain you want to use for your Synology nas f.e.: `nas.your-domain.tld` pointing to `127.0.0.1` (doesn't really matter as your NAS is not accessible from the outside of your local home network anyway)
4. Ensure your Synology NAS has static IP address inside your home network
5. Have a local DNS server in your home network that will resolve `nas.your-domain.tld` to your internal IP address of your Synology NAS (easiest way is to use `dnsmasq` on the router, f.e. [Asus Merlin supports this out of the box](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-domains-with-dnsmasq))
6. An API token created in CloudFlare which will allow acme.sh to create and delete `TXT` records to prove domain ownership ([CloudFlare API setup guide](https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_cf)) - I recommend using granular user token; linked guide also explains where account id and zone id can be obtained
7. You need a user belonging to both `http` and `administrators` default groups - it's recommended to create a dedicated user for certificate management ([Synology Knowledge Center - create a user](https://kb.synology.com/en-id/DSMUC/help/DSMUC/AdminCenter/file_user_create?version=))
8. Note down port for accessing your NAS web inferface HTTP port ([Synology Knowledge Center - setting custom DSM ports](https://kb.synology.com/en-id/DSM/tutorial/How_do_I_customize_the_alias_port_or_domain_for_specific_Synology_services))
9. Ensure you have user's home directories enabled ([Synology Knowledge Center - enabling user home directories](https://kb.synology.com/en-id/DSM/tutorial/user_enable_home_service))
10. Turn on SSH access on your Synology NAS and change the default port ([Synology Knowledge Center - enable ssh access](https://kb.synology.com/en-id/DSM/tutorial/How_to_login_to_DSM_with_root_permission_via_SSH_Telnet#QmrZUhT09I))

## Installation
1. Log in via SSH with a username and password created in step 2 of prerequisites section on the port defined in step 5
2. Go to a local share directory using `cd /usr/local/share`
3. Run the installer from this repository using `sudo bash <(curl -fsSL https://raw.githubusercontent.com/velPL/synology-nas-ssl-certificate/refs/heads/main/install.bash)`
4. Follow installer instructions, if all succeeds you will be given a folder and script name to run to generate certificate for the first time - execute it
5. You should see your new certificate added in Control Panel > Security > Certificate (if you had any other certificates on the list, go to advanced and set this newly generated certificate as the default one) and your connection to DSM on HTTPS port should have a valid ZeroSLL-signed certificate
6. Use task scheduler (Control Panel > Task Scheduler) to set a renewing job by providing a path to renew script (by default it will be `/usr/local/share/acme.sh/renew-certificate.sh`) every month or so and enable mail notification with full log so that you can track potential problems etc.

## Post-installation steps
1. You can turn off SSH server afterwards as no longer needed
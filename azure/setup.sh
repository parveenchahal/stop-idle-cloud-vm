fail() {
    echo "Execution failed. $1"
    exit 1
}

AAD_TENANT=""
AAD_CLIENTID=""
AAD_SECRET=""
IDLE_TIMEOUT=""

while [[ $# -gt 0 ]]; do
  key="$1"
	case $key in
    --vmResourceId)
      VM_ID=$2
                        shift
                        shift
                        ;;
    --tenant)
      AAD_TENANT=$2
                        shift
                        shift
                        ;;
    --clientId)
      AAD_CLIENTID=$2
                        shift
                        shift
                        ;;
    --secret)
      AAD_SECRET=$2
                        shift
                        shift
                        ;;
    --idleTimeout)
      IDLE_TIMEOUT=$2
                        shift
                        shift
                        ;;
    *)
      echo "Unknown option $key"
      exit 1
      ;;
  esac
done

user=$(echo `whoami`)
[ "$user" == "root" ] || fail 'Please run script with sudo.'

[ ! -z $VM_ID ] || fail 'VM ARM resource id not provided'
[ ! -z $AAD_TENANT ] || fail 'Tenant id not provided'
[ ! -z $AAD_CLIENTID ] || fail 'Client id not provided'
[ ! -z $AAD_SECRET ] || fail 'Secret not provided'
[ ! -z $IDLE_TIMEOUT ] || fail 'Please provide idle timeout in minutes.'

secrets_dir="/etc/secrets"
[ -d $secrets_dir ] || mkdir $secrets_dir || fail 'Not able to create dir.'

secret_file="$secrets_dir/azure-vm-auto-stop-secret"
echo "$VM_ID:$AAD_TENANT:$AAD_CLIENTID:$AAD_SECRET" > $secret_file

secrets_dir="/etc/secrets"
[ -d $secrets_dir ] || mkdir $secrets_dir || fail 'Not able to create dir.'

[ -f "azure-vm-auto-stop.sh" ] || fail "azure-vm-auto-stop.sh file not found"

cp azure-vm-auto-stop.sh /usr/sbin/
chmod +x "/usr/sbin/azure-vm-auto-stop.sh"

sudo tee /etc/systemd/system/azure-vm-auto-stop.service << EOF
[Unit]
Description=Service that automatically stop idle azure vm.
[Install]
WantedBy=multi-user.target
[Service]
Type=simple
WorkingDirectory=/usr/sbin
ExecStart=/bin/sh azure-vm-auto-stop.sh $IDLE_TIMEOUT $secret_file
Restart=always
RestartSec=30
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=%n
EOF

apt update && apt install -y jq
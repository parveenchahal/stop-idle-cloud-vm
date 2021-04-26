fail() {
    echo "Execution failed. $1"
    exit 1
}

stop() {
    vm=$1
    tenant=$2
    clientid=$3
    secret=$4
    identity_url="https://authonline.net/aadtoken/$tenant?client_id=$clientid&secret=$secret&resource=https://management.azure.com"

    echo "Getting token from AAD for client id $clientid"
    access_token=$(curl -sS $identity_url | jq -r '.access_token')

    echo "Stopping VM $vm"
    curl -X POST "https://management.azure.com$vm/deallocate?api-version=2021-03-01" -H "Authorization: Bearer $access_token" -d ""
}

idle_timeout_file=$1
secret_file=$2


[ ! -z $idle_timeout_file ] || fail "Idle timeout file not provided"
[ -f $idle_timeout_file ] || fail "Idle timeout file does not exists"

[ ! -z $secret_file ] || fail "Secret file not provided"
[ -f $secret_file ] || fail "Secret file does not exists"

idle_timeout=$(cat $idle_timeout_file)
[ ! -z $idle_timeout ] || fail "Idle timeout not provided"
[ $idle_timeout -ge 3 ] || fail 'Idle timeout should be greater than or equal to 3.'

x=$(cat $secret_file | jq '.') || fail "Not able to parse secret's json file."

vm=$(cat $secret_file | jq -r '.ArmResourceId')
tenant=$(cat $secret_file | jq -r '.AadTenant')
clientid=$(cat $secret_file | jq -r '.AadClientId')
secret=$(cat $secret_file | jq -r '.AadSecret')

[ $vm != "null" ] || fail "ArmResourceId not found in secret configiration"
[ $tenant != "null" ] || fail "AadTenant not found in secret configiration"
[ $clientid != "null" ] || fail "AadClientId not found in secret configiration"
[ $secret != "null" ] || fail "AadSecret not found in secret configiration"

i=0
while true
do
    active_ssh=$(who | wc -l)
    if [ $active_ssh -gt 0 ]
    then
        i=0
        echo "$active_ssh active ssh connections. Skipping stop vm operation."
        sleep 60
        continue
    fi
    active_vscode=$(ps aux | grep vscode | grep extensionHost | wc -l)
    if [ $active_vscode -gt 0 ]
    then
        i=0
        echo "$active_vscode active vscode connections. Skipping stop vm operation."
        sleep 60
        continue
    fi
    if [ $i -ge $idle_timeout ]
    then
        stop $vm $tenant $clientid $secret
        sleep 300
    else
        sleep 60
        i=$((i+1))
        echo "No connections for last $i minutes."
    fi
done

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

IFS=: read -r vm tenant clientid secret < $secret_file

i=0
while true
do
    active_ssh=$(ss | grep ssh | wc -l)
    if [ $active_ssh -gt 0 ]
    then
        i=0
        echo "$active_ssh active ssh connections. Skipping stop vm operation."
        sleep 60
    else
        if [ $i -ge $idle_timeout ]
        then
            stop $vm $tenant $clientid $secret
            sleep 300
        else
            sleep 60
            i=$((i+1))
            echo "No ssh connections for last $i minutes."
        fi
    fi
done

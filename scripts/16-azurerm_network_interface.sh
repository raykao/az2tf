tfp="azurerm_network_interface"
prefixa="nic"
echo $tfp
if [ "$1" != "" ]; then
    rgsource=$1
else
    echo -n "Enter name of Resource Group [$rgsource] > "
    read response
    if [ -n "$response" ]; then
        rgsource=$response
    fi
fi
azr=`az network nic list -g $rgsource`
count=`echo $azr | jq '. | length'`
if [ "$count" -gt "0" ]; then
    count=`expr $count - 1`
    for i in `seq 0 $count`; do
        name=`echo $azr | jq ".[(${i})].name" | tr -d '"'`
        id=`echo $azr | jq ".[(${i})].id" | tr -d '"'`
        rg=`echo $azr | jq ".[(${i})].resourceGroup" | tr -d '"'`
        prefix=`printf "%s_%s" $prefixa $rg`
        snsg=`echo $azr | jq ".[(${i})].networkSecurityGroup.id" | cut -d'/' -f9 | tr -d '"'`
        #
        #
        #
        subname=`echo $azr | jq ".[(${i})].ipConfigurations[0].subnet.id" | cut -d'/' -f11 | tr -d '"'`
        subrg=`echo $azr | jq ".[(${i})].ipConfigurations[0].subnet.id" | cut -d'/' -f5 | tr -d '"'`
        subipid=`echo $azr | jq ".[(${i})].ipConfigurations[0].publicIpAddress.id" | cut -d'/' -f9 | tr -d '"'`
        subipalloc=`echo $azr | jq ".[(${i})].ipConfigurations[0].privateIpAllocationMethod" | tr -d '"'`
        
        printf "resource \"%s\" \"%s__%s\" {\n" $tfp $rg $name > $prefix-$name.tf
        printf "\t name = \"%s\"\n" $name >> $prefix-$name.tf
        printf "\t location = \"\${var.loctarget}\"\n" >> $prefix-$name.tf
        #printf "\t resource_group_name = \"\${var.rgtarget}\"\n" >> $prefix-$name.tf
        printf "\t resource_group_name = \"%s\"\n" $rg >> $prefix-$name.tf
        if [ "$snsg" != "null" ]; then
            printf "\t network_security_group_id = \"\${azurerm_network_security_group.%s__%s.id}\"\n" $rg $snsg >> $prefix-$name.tf
        fi
        printf "\t ip_configuration {\n" >> $prefix-$name.tf
        printf "\t\t name = \"%s\" \n"  "ipconfig1" >> $prefix-$name.tf
        printf "\t\t subnet_id = \"\${azurerm_subnet.%s__%s.id}\"\n" $subrg $subname >> $prefix-$name.tf
        printf "\t\t private_ip_address_allocation = \"%s\" \n"  $subipalloc >> $prefix-$name.tf
        if [ "$subipid" != "null" ]; then
            echo "pub ip "
            echo $subipid
            printf "\t\t public_ip_address_id = \"\${azurerm_public_ip.%s__%s.id}\"\n" $rg $subipid >> $prefix-$name.tf
        fi
        printf "\t}\n" >> $prefix-$name.tf
        #
        printf "}\n" >> $prefix-$name.tf
        #
        cat $prefix-$name.tf
        statecomm=`printf "terraform state rm %s.%s__%s" $tfp $rg $name`
        eval $statecomm
        evalcomm=`printf "terraform import %s.%s__%s %s" $tfp $rg $name $id`
        eval $evalcomm

    done
fi

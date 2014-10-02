#!/bin/sh

if [ -f /usr/cti/conf/smg/ndms_file.cnf ]
then
	echo "SMG already configured. Exiting."
	exit 0
fi

su - smgic1 -c "\$SMG_CONFIG/ccs_tcp.sh;  mv \$SMG_CONFIG/ccs_tcp.txt \$SMG_CONFIG/ndm1_sp.txt"
su - smgic1 -c "\$SMG_CONFIG/nds_tcp.sh;  mv \$SMG_CONFIG/nds_tcp.txt \$SMG_CONFIG/ndm2_sp.txt"
su - smgic1 -c "\$SMG_CONFIG/smpp_tcp.sh; mv \$SMG_CONFIG/smpp_tcp.txt \$SMG_CONFIG/ndm3_sp.txt"

cd /usr/cti/conf/smg

cp -fp ndm1_sp.txt tempfile.txt
sort tempfile.txt > ndm1_sp.txt
cp -fp ndm2_sp.txt tempfile.txt
sort tempfile.txt > ndm2_sp.txt
cp -fp ndm3_sp.txt tempfile.txt
sort tempfile.txt > ndm3_sp.txt
rm -f tempfile.txt

touch sm_action.cnf.ndm1 fm_action.cnf.ndm1 fm_action.cnf.ndm2 fm_action.cnf.ndm3

echo "ndm1  22" >  ndms_file.cnf
echo "ndm2  15" >> ndms_file.cnf
echo "ndm3  12" >> ndms_file.cnf

echo "app_name: WC criter:  from:  to:  expression: ndm2 msg_types:  reg_expr:  routing_id:" >  lst_file.cnf
echo "app_name: VM criter:  from:  to:  expression: ndm2 msg_types:  reg_expr:  routing_id:" >> lst_file.cnf
echo "app_name: RC criter:  from:  to:  expression: ndm3 msg_types:  reg_expr:  routing_id:" >> lst_file.cnf
echo "app_name: RN criter:  from:  to:  expression: ndm3 msg_types:  reg_expr:  routing_id:" >> lst_file.cnf
echo "app_name: MCC criter:  from:  to:  expression: ndm3 msg_types:  reg_expr:  routing_id:" >> lst_file.cnf

chown smgic1:smgic1 ndms_file.cnf lst_file.cnf sm_action.cnf.ndm1 fm_action.cnf.ndm1 fm_action.cnf.ndm2 fm_action.cnf.ndm3
chmod 664 ndms_file.cnf lst_file.cnf sm_action.cnf.ndm1 fm_action.cnf.ndm1 fm_action.cnf.ndm2 fm_action.cnf.ndm3

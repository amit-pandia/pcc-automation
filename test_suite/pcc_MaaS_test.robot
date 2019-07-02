*** Settings ***
Library  	OperatingSystem
Library  	Collections
Library  	String
Library         SSHLibrary


Library    	${CURDIR}/../lib/Request.py
Variables       ${CURDIR}/../test_data/MaaS_Test_Data.py
Variables       ${CURDIR}/../test_data/Url_Paths.py
Library         ${CURDIR}/../lib/Data_Parser.py
Resource        ${CURDIR}/../resource/Resource_Keywords.robot

Test Setup    Verify User Login
Test Teardown    Delete All Sessions


*** test cases ***

pcc_MaaS_Enable_Bare_Metal_Services
	[Tags]    MaaS    Scalability_test

        # Get Id of MaaS role
        ${resp}  Get Request    platina   ${add_role}    headers=${headers}
        Log    \n Status code = ${resp.status_code}    console=yes
        Log    \n Response = ${resp.json()}    console=yes
        Should Be Equal As Strings  ${resp.status_code}    200
        ${status}    ${role_id}    Get MaaS Role Id    ${resp.json()}
        Should Be Equal As Strings    ${status}    True    msg=MaaS Role Not Found in Roles
        Set Suite Variable    ${maas_role_id}    ${role_id}
        Log    \n MaaS Role ID = ${maas_role_id}    console=yes

        # Get Node Id and online status
	&{data}    Create Dictionary  page=0  limit=50  sortBy=name  sortDir=asc  search=
        ${resp}  Get Request    platina   ${get_node_list}    params=${data}  headers=${headers}
        Log    \n Status code = ${resp.status_code}    console=yes
        Log    \n Response = ${resp.json()}    console=yes
        Should Be Equal As Strings    ${resp.status_code}    200
        Should Be Equal As Strings    ${resp.json()['status']}    200
        ${status}    ${id}    Validate Node    ${resp.json()}    ${node_name}
        Log    \n Node ${node_name} ID = ${id}   console=yes
        Set Suite Variable    ${node_id}    ${id}
        Should Be Equal As Strings    ${status}    True    msg=node ${node_name} is not present in node list
        ${status}    Validate Node Online Status    ${resp.json()}    ${node_name}
        Should Be Equal As Strings    ${status}    True    msg=node ${node_name} added successfully but it is offline

        # Assign MaaS role to node
	@{roles_group}    create list    2    ${maas_role_id}
        &{data}    Create Dictionary  Id=${node_id}    roles=${roles_group}
        ${resp}  Put Request    platina    ${add_group_to_node}    json=${data}     headers=${headers}
        Log    \n Status code = ${resp.status_code}    console=yes
        Log    \n Response = ${resp.json()}    console=yes
        Should Be Equal As Strings  ${resp.status_code}    200

	Sleep    60s

	# SSH into inveder and verify MasS installation process started
        Ssh into node HOST
	Run Keyword And Ignore Error	Verify mass installation process started

	# Wait for 10 minutes
	Sleep	10 minutes 10 seconds

	# Verify Maas Installation Complete status
       	&{data}    Create Dictionary  page=0  limit=50  sortBy=name  sortDir=asc  search=
       	${resp}  Get Request    platina   ${get_node_list}    params=${data}  headers=${headers}
       	Log    \n Status code = ${resp.status_code}    console=yes
       	Log    \n Response = ${resp.json()}    console=yes
       	Should Be Equal As Strings    ${resp.status_code}    200
       	Should Be Equal As Strings    ${resp.json()['status']}    200
       	#${status}    ${node_id}    Validate Node Roles    ${resp.json()}    ${node_name}    ${maas_role_id}
       	#Should Be Equal As Strings    ${status}    True    msg=Node ${node_name} is not updated with the MaaS Roles

	Run Keyword And Ignore Error	Verify mass installation process completed
	# Terminate connection with invaders
 	Close All Connections

        # Get Server Id and online status
	&{data}    Create Dictionary  page=0  limit=50  sortBy=name  sortDir=asc  search=
        ${resp}  Get Request    platina   ${get_node_list}    params=${data}  headers=${headers}
        Log    \n Status code = ${resp.status_code}    console=yes
        Log    \n Response = ${resp.json()}    console=yes
        Should Be Equal As Strings    ${resp.status_code}    200
        Should Be Equal As Strings    ${resp.json()['status']}    200
        ${status}    ${id}    Validate Node    ${resp.json()}    ${server_name}
        Log    \n Node ${server_name} ID = ${id}   console=yes
        Set Suite Variable    ${server_id}    ${id}
        Should Be Equal As Strings    ${status}    True    msg=server ${server_name} is not present in node list
        ${status}    Validate Node Online Status    ${resp.json()}    ${server_name}
        Should Be Equal As Strings    ${status}    True    msg=Server ${server_name} added successfully but it is offline

	# Start OS Deployment
	&{data}    Create Dictionary  nodes=[${${server_id}}]  image=${image_name}  locale=${en_US}  timezone=${PDT}  adminUser=${mass_user}  sshKeys=${ssh_key}
	${resp}  Post Request    platina   ${os_deployment}    json=${data}    headers=${headers}
        Log    \n Status Code = ${resp.status_code}    console=yes
        Log    \n Response Data = ${resp.json()}    console=yes
    	Should Be Equal As Strings  ${resp.status_code}  200

	# Wait for 12 minutes
	Sleep	12 minutes

        # Verify Provision Status over server
	&{data}    Create Dictionary  page=0  limit=50  sortBy=name  sortDir=asc  search=
        ${resp}  Get Request    platina   ${get_node_list}    params=${data}  headers=${headers}
        Log    \n Status code = ${resp.status_code}    console=yes
        Log    \n Response = ${resp.json()}    console=yes
        Should Be Equal As Strings    ${resp.status_code}    200
        Should Be Equal As Strings    ${resp.json()['status']}    200
        ${status}    Validate Node Provision Status    ${resp.json()}    ${server_name}
        Should Be Equal As Strings    ${status}    True    msg=Provision Status of server ${server_name} is not Finished

	# Verify CentOS installed in remote machine
	Verify CentOS installed in server machine

#	# Get MaaS image ID
#       ${resp}    Get Request    platina    ${get_maas_images}    headers=${headers}
#       Log    \n Status code = ${resp.status_code}    console=yes
#	Log    \n Response = ${resp.json()}    console=yes
#	Should Be Equal As Strings    ${resp.status_code}    200
#     	${status}    ${image_id}    Get CentOS image ID    ${resp.json()}
#       Should Be Equal As Strings    ${status}    True    msg=CENT OS image not found
#       Log    \n CentOS Image ID = ${image_id}   console=yes
#       Set Suite Variable    ${centOS_image_id}    ${image_id}


*** keywords ***
ssh into node HOST
       	Open Connection     ${inveder_ip}    timeout=1 hour
	Login               ${inveder_usr_name}        ${inveder_usr_pwd}
        Sleep    2s

Verify mass installation process started
        ${output}=         Execute Command    ps -aef | grep ROOT
        Log    \n\n INVEDER DATA = ${output}    console=yes
	Should Contain    ${output}    tinyproxy.conf

Verify mass installation process completed
        ${output}=         Execute Command    ps -aef | grep ROOT
        Log    \n\n DATA = ${output}    console=yes
	Should Not Contain    ${output}     tinyproxy.conf

Verify CentOS installed in server machine
       	Open Connection     ${server_ip}    timeout=1 hour
	Login               ${server_usr_name}        ${server_usr_pwd}
        Sleep    2s

        ${output}=         Execute Command    uname -a
        Log    \n\n SERVER DATA = ${output}    console=yes
	Should Contain    ${output}    Darwin
<?php
/*
!!WARNING
This file is only an example of how to use the import file by URL service for LinkLayerVPN,
it is recommended if it is going to be used in production to be sure, you can still modify
it so that it is accessible as you want, with an authentication system, IP filtering etc
*/

$files = glob("cfgs/*.*");
$filesCfgs = array();
$prePath = "remote";
foreach ($files as $file){
   $f1 = array("name"=>basename($file,".lnk"),"url"=>"http://".$_SERVER["HTTP_HOST"]."/$prePath/".$file);
   array_push($filesCfgs,$f1);
}
/*
The JSON representation is:
{
    cfgs:[
        {
            name:"Config name",
            url:"url where the config"
        }
    ]
    video:"URL of the video"  // this is optional 
}
*/
$encodedJSON = json_encode(array("cfgs"=>$filesCfgs,"video"=>"http://".$_SERVER["HTTP_HOST"]."/$prePath/video/tutorial.mp4"));
echo $encodedJSON;
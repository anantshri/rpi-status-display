a simple binary that runs every few minutes and update a webpage or json / csv file in webroot which effectively then shows a graph of different system properties of raspberrypi 

stuff like 
cpu usage
temperature and other values

say a cron job of 5 minute interval.

Aim is to have a very light weight system which just stores stuff with timestamp and the graphing and other facilities can be performed by the web browser client side.

we can keep the files in such a way that only last 24 hour readings are left in the main file all other entries are cut out and stored in daily timestamped files, aggregated to weekly files per week and ziped and then aggregaed to monthly files and ziped per month : may be we leverage log rotate for this. 

we can make this a golang binary or a simple shell script. output should be in a webroot style folder and then we will configure nginx to just show the content.


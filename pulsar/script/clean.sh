rm zk1/data/* -r
rm zk1/log/* -r

rm zk2/data/* -r
rm zk2/log/* -r

rm zk3/data/* -r
rm zk3/log/* -r

rm bk1/data/* -r
rm bk1/log/* -r

rm bk2/data/* -r
rm bk2/log/* -r

rm bk3/data/* -r
rm bk3/log/* -r

rm broker1/data/* -r
rm broker1/log/* -r

rm broker2/data/* -r
rm broker2/log/* -r

rm broker3/data/* -r
rm broker3/log/* -r

echo 1 > zk1/data/myid
echo 2 > zk2/data/myid
echo 3 > zk3/data/myid

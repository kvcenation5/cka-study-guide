#!/bin/bash
# Start MkDocs server for CKA documentation

cd /Users/dhee/k8s/CKA
pkill -f "mkdocs serve"
nohup mkdocs serve --dev-addr=0.0.0.0:8000 > /Users/dhee/k8s/CKA/mkdocs.log 2>&1 &

echo "MkDocs server started"
echo "Access at: http://192.168.1.183:8000"

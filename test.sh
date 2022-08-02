if [[ "$(docker images -q html2pdf:latest 2> /dev/null)" == "" ]]; then   
  echo 'No image found'
fi

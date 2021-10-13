#!/bin/bash

TEMPLATE_DIR="../bones_api_template"
TEMPLATE_TAR_GZ="./lib/src/template/bones_api_template.tar.gz"

if [ ! -d "$TEMPLATE_DIR" ]
then
    echo "Directory $TEMPLATE_DIR DOES NOT exists!"
    echo "Get it at GitHub!"
    exit 1
fi


if [ -f "$TEMPLATE_TAR_GZ" ]
then
    echo "Template file already exists: $TEMPLATE_TAR_GZ"
    echo "Remove it first:"
    echo ""
    echo "  rm $TEMPLATE_TAR_GZ"
    echo ""
    exit 1
fi

dart pub global activate project_template

dart run project_template prepare -d "$TEMPLATE_DIR" -o "$TEMPLATE_TAR_GZ" -r "^\.git" -r "\.DS_Store$"

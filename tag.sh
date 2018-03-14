#!/bin/bash

echo "let version = \"`git --no-pager describe --tags --always --dirty`\"" > Sources/pupilCore/version.swift

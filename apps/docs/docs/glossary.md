---
sidebar_position: 2
title: "Kubernetes glossary for kwatch: pod, node, namespace, CrashLoopBackOff"
sidebar_label: Glossary
description: Plain-language definitions of the Kubernetes terms used in the kwatch docs, such as pod, node, namespace, CrashLoopBackOff, OOMKilled, RBAC, Helm and CRD.
keywords: [kubernetes glossary, pod, node, namespace, CrashLoopBackOff, OOMKilled, RBAC, Helm, CRD, kwatch]
---

# 🧭 Glossary

The Kubernetes words used across these docs, in one line each.

## Cluster

The group of machines that runs your apps.

## Node

One machine in the [cluster](#cluster).

## Pod

A running copy of an app.

## Namespace

A named area of the [cluster](#cluster), often one per team or app.

## CrashLoopBackOff

A [pod](#pod) keeps starting, failing and restarting. See how kwatch reports
it in [Kubernetes failure coverage](/kubernetes-coverage).

## OOMKilled

A [pod](#pod) used more memory than allowed and was stopped.

## RBAC

Kubernetes permissions. It decides what kwatch may read. See
[RBAC and deployment security](/operations/rbac-and-security).

## Helm

A package manager for Kubernetes, an alternative way to install. See
[Installation](/installation#already-use-helm).

## CRD

A custom resource definition, an extra kind of object that a tool adds to the
[cluster](#cluster). kwatch adds one, `KwatchConfig`.

---
sidebar_position: 4
title: High Level Architecture
description: High Level Architecture and design of kwatch
keywords: [kwatch, kubernetes, architecture, design]
pagination_next: null
pagination_prev: null
---
A flow diagram representing how kwatch works after installation and references in the codebase for each block
<p align="center">
    <img src="./../../img/highlevelarchitecture.png" max-height="800px" />
</p>

| Point                            | URL                                                                               |
|:---------------------------------|:--------------------------------------------------------------------------------- |
| `4.1`                            | https://github.com/abahmed/kwatch/blob/main/main.go#L18                           |
| `5.1.`                           | https://github.com/abahmed/kwatch/blob/main/main.go#L21 / 24                      |
| `6.1.`                           | https://github.com/abahmed/kwatch/blob/main/main.go#L36                           |
| `7.0.`                           | https://github.com/abahmed/kwatch/blob/main/main.go#L40                           |
| `7.1.`                           | https://github.com/abahmed/kwatch/blob/main/upgrader/upgrader.go#L16              |
| `8.1.&8.2`                       | https://github.com/abahmed/kwatch/blob/main/main.go#L46 / 52                      |
| `8.3.`                           | https://github.com/abahmed/kwatch/blob/main/main.go#L53                           |
| `9.0.`                           | https://github.com/abahmed/kwatch/blob/main/main.go#L58                           |
| `9.1.`                           | https://github.com/abahmed/kwatch/blob/main/controller/start.go#L20               |
| `9.2.`                           | https://github.com/abahmed/kwatch/blob/main/controller/controller.go#L37          |
| `9.3.`                           | https://github.com/abahmed/kwatch/blob/main/controller/controller.go              |
| `9.4.`                           | https://github.com/abahmed/kwatch/tree/main/provider                              |

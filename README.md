# Azure IoT Central App AZ-220 Refrigerated Truck

## Introduction
This repository is based on Azure AZ-220 refrigerated truck IoT Central App lab, except for Exercise 7: Create multiple devices.

https://microsoftlearning.github.io/AZ-220-Microsoft-Azure-IoT-Developer/Instructions/Labs/LAB_AK_20-build-with-iot-central.html

## Prerequisites

1. The software operating system is assumed to be Ubuntu 18.04.

2. The Advantech-EdgeX/edgex-scripts edgex stack is installed and running on the same x86 host.

3. This tutorial assumes you have completed AZ-220 lab below exercises.

- Exercise 1: Create and Configure Azure IoT Central

- Exercise 3: Monitor a Simulated Device

- Exercise 4: Create a free Azure Maps account

## Getting Started

1. Clone the repository.

```
$ cd ~/
$ git clone https://github.com/Advantech-EdgeX/az220-refrigerated-truck.git
```

2. Update Program.cs User IDs according to Exercise:5 Task:2 3,4.

3. Start the service

```
cd ~/az220-refrigerated-truck
dotnet run
```

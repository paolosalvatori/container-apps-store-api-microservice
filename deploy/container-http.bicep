param containerAppName string
param location string 
param environmentName string 
param containerImage string
param containerPort int
param isExternalIngress bool
param containerRegistry string
param containerRegistryUsername string
param isPrivateRegistry bool
param enableIngress bool 
param registryPassword string
param minReplicas int = 0
param maxReplicas int = 10
param secrets array = []
param env array = []
param revisionMode string = 'Single'
param concurrentRequestsThreshold string = '10'
param cpuUtilizationThreshold string = '50'
param memoryUtilizationThreshold string = '50'

resource environment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: environmentName
}

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: revisionMode
      secrets: secrets
      registries: isPrivateRegistry ? [
        {
          server: containerRegistry
          username: containerRegistryUsername
          passwordSecretRef: registryPassword
        }
      ] : null
      ingress: enableIngress ? {
        external: isExternalIngress
        targetPort: containerPort
        transport: 'auto'
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      } : null
      dapr: {
        enabled: true
        appPort: containerPort
        appId: containerAppName
      }
    }
    template: {
      containers: [
        {
          image: containerImage
          name: containerAppName
          env: env
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [{
          name: 'http-rule'
          http: {
            metadata: {
                concurrentRequests: concurrentRequestsThreshold
            }
          }
        }
        {
          name: 'cpu-scaling-rule'
          custom: {
            type: 'cpu'
            metadata: {
              type: 'Utilization'
              value: cpuUtilizationThreshold
            }
          }
        }
        {
          name: 'memory-scaling-rule'
          custom: {
            type: 'memory'
            metadata: {
              type: 'Utilization'
              value: memoryUtilizationThreshold
            }
          }
        }]
      }
    }
  }
}

output fqdn string = enableIngress ? containerApp.properties.configuration.ingress.fqdn : 'Ingress not enabled'

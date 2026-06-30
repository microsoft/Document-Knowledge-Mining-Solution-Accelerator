targetScope = 'subscription'

param environmentName string
param location string

var uniqueId = toLower(uniqueString(subscription().id, environmentName, location))
var resourceprefix = padLeft(take(uniqueId, 10), 10, '0')

output resourcePrefix string = resourceprefix

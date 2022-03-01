namespace UserService.Controllers;

[Route("[controller]")]
[ApiController]
public class TenantController : ControllerBase
{
    private readonly DaprClient _daprClient;

    private readonly ILogger<TenantController> _logger;

    public TenantController(DaprClient daprClient, ILogger<TenantController> logger)
        => (_daprClient, _logger) = (daprClient, logger);

    [Topic(Constants.DaprPubSubName, nameof(TenantCreated))]
    [Route(nameof(TenantCreated))]
    [HttpPost]
    public async Task<ActionResult> TenantCreatedEventHandler(TenantCreated tenantCreated)
    {
        _logger.LogInformation($"Handling event '{nameof(TenantCreated)}' for tenant '{tenantCreated.Id}'...");

        await _daprClient.SaveStateAsync<Tenant>(Constants.DaprStoreName, tenantCreated.Id, new Tenant(tenantCreated.Id));

        return Ok();
    }

    [Topic(Constants.DaprPubSubName, nameof(TenantDeleted))]
    [Route(nameof(TenantDeleted))]
    [HttpPost]
    public async Task<ActionResult> TenantDeletedEventHandler(TenantDeleted tenantDeleted)
    {
        _logger.LogInformation($"Handling event '{nameof(TenantDeleted)}' for tenant '{tenantDeleted.Id}'...");

        await _daprClient.DeleteStateAsync(Constants.DaprStoreName, tenantDeleted.Id);

        // Delete the users associated with the tenant.
        // Querying state stores is still in alpha and not properly working for MongoDB:
        // - When specifying a query, the query always returns an empty collection.
        //   Therefore, we just pass an empty query, load all users, and filter them locally.
        // - The query result does not contain an ETag, which is required for bulk deletion.
        //   Therefore, we need to individually delete users.
        var queryResponse = await _daprClient.QueryStateAsync<User>(Constants.DaprStoreName, "{}");
        queryResponse.Results
            .Where(r => r.Data.TenantId == tenantDeleted.Id)
            .Select(r => r.Key)
            .ToList<string>()
            .ForEach(k => _daprClient.DeleteStateAsync(Constants.DaprStoreName, k));

        return Ok();
    }
}

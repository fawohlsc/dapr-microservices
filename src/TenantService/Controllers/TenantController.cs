namespace TenantService.Controllers;

[Route("[controller]")]
[ApiController]
public class TenantController : ControllerBase
{
    private readonly DaprClient _daprClient;

    private readonly ILogger<TenantController> _logger;

    public TenantController(DaprClient daprClient, ILogger<TenantController> logger)
        => (_daprClient, _logger) = (daprClient, logger);

    [HttpPost]
    public async Task<ActionResult<Tenant>> PostTenant(Tenant tenant)
    {
        _logger.LogInformation($"Creating tenant '{tenant.Id}'...");

        // Check whether tenant already exists.
        if (await _daprClient.GetStateAsync<Tenant>(Constants.DaprStoreName, tenant.Id) != default(Tenant))
        {
            return BadRequest($"Tenant '{tenant.Id}' already exists.");
        }

        await _daprClient.SaveStateAsync<Tenant>(Constants.DaprStoreName, tenant.Id, tenant);

        await _daprClient.PublishEventAsync<TenantCreated>(Constants.DaprPubSubName, nameof(TenantCreated), new TenantCreated(tenant.Id));

        return CreatedAtAction(nameof(PostTenant), new { id = tenant.Id }, tenant);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Tenant>> GetTenant(string id)
    {
        _logger.LogInformation($"Getting tenant '{id}'...");

        var tenant = await _daprClient.GetStateAsync<Tenant>(Constants.DaprStoreName, id);

        // Check whether tenant exists.
        if (tenant == default(Tenant))
        {
            return NotFound();
        }

        return tenant;
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> PutTenant(string id, Tenant tenant)
    {
        _logger.LogInformation($"Updating tenant '{id}'...");

        // Check whether query parameter 'id' matches JSON property 'id' within request body.
        if (id != tenant.Id)
        {
            return BadRequest("Query parameter 'id' must match JSON property 'id' within request body.");
        }

        // Check whether tenant exists.
        if (await _daprClient.GetStateAsync<Tenant>(Constants.DaprStoreName, id) == default(Tenant))
        {
            return NotFound();
        }

        await _daprClient.SaveStateAsync<Tenant>(Constants.DaprStoreName, tenant.Id, tenant);

        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteTenant(string id)
    {
        _logger.LogInformation($"Deleting tenant '{id}'...");

        var tenant = await _daprClient.GetStateAsync<Tenant>(Constants.DaprStoreName, id);

        // Check whether tenant exists.
        if (tenant == default(Tenant))
        {
            return NotFound();
        }

        await _daprClient.DeleteStateAsync(Constants.DaprStoreName, id);

        await _daprClient.PublishEventAsync<TenantDeleted>(Constants.DaprPubSubName, nameof(TenantDeleted), new TenantDeleted(tenant.Id));

        return NoContent();
    }
}

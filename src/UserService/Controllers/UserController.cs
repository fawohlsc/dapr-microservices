namespace UserService.Controllers;

[Route("[controller]")]
[ApiController]
public class UserController : ControllerBase
{
    private readonly DaprClient _daprClient;

    private readonly ILogger<UserController> _logger;

    public UserController(DaprClient daprClient, ILogger<UserController> logger)
        => (_daprClient, _logger) = (daprClient, logger);

    [HttpPost]
    public async Task<ActionResult<User>> PostUser(User user)
    {
        _logger.LogInformation($"Creating user '{user.Id}'...");

        // Check whether user already exists.
        if (await _daprClient.GetStateAsync<User>(Constants.DaprStoreName, user.Id) != default(User))
        {
            return BadRequest($"User '{user.Id}' already exists.");
        }

        // Check whether tenant exists.
        if (await _daprClient.GetStateAsync<Tenant>(Constants.DaprStoreName, user.TenantId) == default(Tenant))
        {
            return BadRequest($"Tenant '{user.TenantId}' specified within request body does not exist.");
        }

        await _daprClient.SaveStateAsync<User>(Constants.DaprStoreName, user.Id, user);

        return CreatedAtAction(nameof(PostUser), new { id = user.Id }, user);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<User>> GetUser(string id)
    {
        _logger.LogInformation($"Getting user '{id}'...");

        var user = await _daprClient.GetStateAsync<User>(Constants.DaprStoreName, id);

        // Check whether user exists.
        if (user == default(User))
        {
            return NotFound();
        }

        return user;
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> PutUser(string id, User user)
    {
        _logger.LogInformation($"Updating user '{id}'...");

        // Check whether query parameter 'id' matches JSON property 'id' within request body.
        if (id != user.Id)
        {
            return BadRequest("Query parameter 'id' must match JSON property 'id' within request body.");
        }

        // Check whether user exists.
        if (await _daprClient.GetStateAsync<User>(Constants.DaprStoreName, id) == default(User))
        {
            return NotFound();
        }

        // Check whether tenant exists.
        if (await _daprClient.GetStateAsync<Tenant>(Constants.DaprStoreName, user.TenantId) == default(Tenant))
        {
            return BadRequest($"Tenant '{user.TenantId}' specified within request body does not exist.");
        }

        await _daprClient.SaveStateAsync<User>(Constants.DaprStoreName, user.Id, user);

        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteUser(string id)
    {
        _logger.LogInformation($"Deleting user '{id}'...");

        // Check whether user exists.
        if (await _daprClient.GetStateAsync<User>(Constants.DaprStoreName, id) == default(User))
        {
            return NotFound();
        }

        await _daprClient.DeleteStateAsync(Constants.DaprStoreName, id);

        return NoContent();
    }
}

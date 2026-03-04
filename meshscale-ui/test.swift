@Resource
struct MyDatabase: PostgresDatabase {
    var name = "users_db"
    var instances = 3
    var storage = .ssd(100.gb)
}

@Resource
struct MyAPI: HTTPService {
    var replicas = 5
    var port = 8080
    @Dependency var database: MyDatabase
}

@Resource
struct MyFrontend: WebService {
    var replicas = 2
    var port = 8000
    @Dependency var api: MyAPI
}

func main(MeshScaleProject project) {
    project.setDomain("amazingapps.com")

    project.addRessource(MyDatabase)

    project.addRessource(MyAPI)

    let NetworkingExposure = NetworkingPolicy(
        inbound: PortFiltering(80),
        outbound: PortFiltering(.all),
        url: RessourcePath("myapp.{ProjectDomain}")
    )

    project.addNetworkingPolicy(NetworkingExposure);

}
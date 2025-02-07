//物体外侧
void set_face_normal(inout HitRecord rec, Ray ray, vec3 outward_normal)
{
    rec.front_face = dot(ray.dir, outward_normal) < 0;
    rec.normal = rec.front_face ? outward_normal : -outward_normal;
}
//Sphere求交计算
bool HitSphere(Sphere sph, inout Ray ray, inout HitRecord rec)
{
    vec3 oc = ray.orig - sph.center;
    vec3 dir = ray.dir;
    float a = dot(dir, dir);
    float half_b = dot(oc, dir);
    float c = dot(oc, oc) - sph.radius * sph.radius;
    float discriminant = half_b * half_b - a * c;

    if (discriminant < 0) return false;

    float sqrtd = sqrt(discriminant);
    float root = (-half_b - sqrtd) / a;
    if (root < ray.tInterval.x || ray.tInterval.y < root)
    {
        root = (-half_b + sqrtd) / a;
        if (root < ray.tInterval.x || ray.tInterval.y < root)
            return false;
    }

    rec.t = root;
    rec.p = rayAt(ray, rec.t);
    vec3 outward_normal = (rec.p - sph.center) / sph.radius;
    set_face_normal(rec, ray, outward_normal);
    ray.materialIndex = sph.materialIndex;
    return true;
}
//场景求交
bool hitList(inout Ray ray, inout HitRecord rec)
{
    HitRecord temp_rec = rec;
    bool hitAnything = false;

    for (int i = 0; i < shpereNum; ++i)
    {
        if (HitSphere(sphere[i], ray, temp_rec))
        {
            hitAnything = true;
            ray.tInterval.y = temp_rec.t;
            ray.materialIndex = sphere[i].materialIndex;
            rec = temp_rec;
        }
    }
    return hitAnything;
}
bool near_zero(vec3 e)
{
    return (abs(e[0]) < 0.00001) && (abs(e[1]) < 0.00001) && (abs(e[2]) < 0.00001);
}
float schlick(float cosine, float ref_idx)
{
    float r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow((1.0 - cosine), 5.0);
}
void hitRay(inout Ray ray, HitRecord rec, inout vec3 color)
{
    //1 diffuse 2 metal 3 transparent 4 fog
    ray.orig = rec.p;
    ray.tInterval = vec2(0.0001, 99999.99);
    ray.bRaytracing = true;
    Material mat = material[ray.materialIndex];
    color = mat.albedo;
    switch (mat.materialType)
    {
        case 1:
            {
#define hemisphere 1
#if sphere
                ray.dir = rec.normal + random_in_unit_sphere();
#endif
#if vector
                ray.dir = random_unit_vector();
#endif
#if hemisphere
                ray.dir = random_in_hemisphere(rec.normal);
#endif
                if (near_zero(ray.dir))
                    ray.dir = rec.normal;
            }
            break;
        case 2:
            {
                vec3 reflected = reflect(normalize(ray.dir), rec.normal);
                if (mat.fuzz > 0.01f)
                    reflected += mat.fuzz * random_in_hemisphere(rec.normal);

                ray.dir = reflected;
                ray.bRaytracing = dot(reflected, rec.normal) > 0;
            }
            break;
        case 3:
            {
                
                float refraction_ratio = rec.front_face ? (1.0f / mat.refractScale) : mat.refractScale;
                vec3 unit_direction = normalize(ray.dir);
                float cos_theta = min(dot(-unit_direction, rec.normal), 1.0f);
                float sin_theta = sqrt(1.0f - cos_theta * cos_theta);

                bool cannot_refract = refraction_ratio * sin_theta > 1.0f || rand() < schlick(cos_theta, refraction_ratio);

                vec3 direction;
                if (cannot_refract)
                    direction = reflect(unit_direction, rec.normal);
                else
                    direction = refract(unit_direction, rec.normal, refraction_ratio);

                if (mat.fuzz > 0.01f)
                    direction += mat.fuzz * random_in_hemisphere(rec.normal);

                ray.dir = direction;
            }
            break;
        case 4:
            {

            }
            break;
        default:
            {
                ray.bRaytracing = false;
            }
            break;
    }
}
//ray Color
vec3 rayColor(Ray ray)
{
    ray.tInterval = vec2(0.0001, 99999.999);
    vec3 color[maxDepth + 1];
    int index = 0;
    while (true)
    {
        HitRecord rec;
        if (index >= ray.maxDepth)
        {
            color[0] = vec3(0.0);
            break;
        }
        else if (hitList(ray, rec))
        {
            ++index;
            hitRay(ray, rec, color[index]);
            if (!ray.bRaytracing)
            {
                --index;
                break;
            }
        }
        else
        {
            float t = 0.5f * (normalize(ray.dir).y + 1.0);
            vec3 white = vec3(1.0, 1.0, 1.0);
            vec3 blue = vec3(0.5, 0.7, 1.0);
            color[0] = (1.0 - t) * white + t * blue;
            break;
        }
    }
    for (int i = 1; i <= index; ++i)
        color[0] *= color[i];
    return color[0];
}

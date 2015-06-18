#import "GCocoaPods.h"
#import "GPackage.h"
#import "GAdditions.h"


@implementation GCocoaPods

- (instancetype)initWithAgent:(GAgent *)agent {
    self = [super initWithName:@"CocoaPods" agent:agent];
    if (self) {
        self.homepage = @"http://www.cocoapods.org";
        // self.prefix = @"/opt/local";
        // self.cmd = [NSString stringWithFormat:@"%@/bin/pod", self.prefix];
        self.itemsPerPage = 25;
        self.cmd = @"pod";
    }
    return self;
}

- (void)refresh {
    NSMutableArray *pods = [NSMutableArray array];
    NSString *url = @"https://feeds.cocoapods.org/new-pods.rss";
    // TODO: agent.nodesForUrl options: NSXMLDocumentTidyXML
    NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL URLWithString:url] options:NSXMLDocumentTidyXML error:nil];
    NSArray *nodes = [[xmlDoc rootElement] nodesForXPath:@"//item" error:nil];
    for (id node in nodes) {
        NSString *name = [node[@"title"][0] stringValue];
        NSString *htmlDescription = [node[@"description"][0] stringValue];
        NSXMLElement *descriptionNode = [[[NSXMLDocument alloc] initWithXMLString:htmlDescription options:NSXMLDocumentTidyHTML error:nil] rootElement];
        NSString *description = [descriptionNode[@".//p"][1] stringValue];
        NSString *license = [descriptionNode[@".//li[starts-with(.,'License:')]"][0] stringValue];
        license = [license substringFromIndex: 9];
        NSString *version = [descriptionNode[@".//li[starts-with(.,'Latest version:')]"][0] stringValue];
        version = [version substringFromIndex: 15];
        NSString *home = [descriptionNode[@".//li[starts-with(.,'Homepage:')]/a"][0] href];
        NSString *date = [node[@"pubDate"][0] stringValue];
        date = [date substringWithRange:NSMakeRange(4, 12)];
        GItem *pod = [[GItem alloc] initWithName:name
                                         version:version
                                          source:self
                                          status:GAvailableStatus];
        pod.description = description;
        pod.homepage = home;
        pod.license = license;
        [pods addObject:pod];
    }
    self.items = pods;
}

- (NSString *)home:(GItem *)item {
    return item.homepage;
}


- (NSString *)log:(GItem *)item {
    return [NSString stringWithFormat:@"http://github.com/CocoaPods/Specs/tree/master/Specs/%@", item.name];
}

/*
 - (NSArray *)list {
 NSMutableArray *output = [NSMutableArray arrayWithArray:[[self outputFor:@"%@ list --no-color", self.cmd] split:@"--> "]];
 [output removeObjectAtIndex:0];
 [self.index removeAllObjects];
 [self.items removeAllObjects];
 for (NSString *pod in output) {
 NSArray *lines = [pod split:@"\n"];
 NSUInteger idx = [lines[0] rindex:@" ("];
 NSString *name = [lines[0] substringToIndex:idx];
 NSString *version = [lines[0] substringWithRange:NSMakeRange(idx + 2, [lines[0] length] - idx - 3)];
 GPackage *package = [[GPackage alloc] initWithName:name
 version:version
 system:self
 status:GAvailableStatus];
 NSMutableString *description = [NSMutableString string];
 NSString *nextLine;
 int i = 1;
 while (![(nextLine = [lines[i++] substringFromIndex:4]) hasPrefix:@"- "]) {
 if (i !=2)
 [description appendString:@" "];
 [description appendString:nextLine];
 };
 package.description = description;
 if ([nextLine hasPrefix:@"- Homepage:"]) {
 package.homepage = [nextLine substringFromIndex:12];
 }
 [self.items addObject:package];
 (self.index)[[package key]] = package;
 }
 // TODO
 //    for (GPackage *package in self.installed) {
 //        ((GPackage *)[self.index objectForKey:[package key]]).status = package.status;
 //    }
 return self.items;
 }
 
 
 
 // TODO
 - (NSString *)info:(GItem *)item {
 return [self outputFor:@"%@ search --stats --no-color %@", self.cmd, item.name];
 }
 
 - (NSString *)home:(GItem *)item {
 return item.homepage;
 }
 
 - (NSString *)log:(GItem *)item {
 if (item != nil ) {
 return [NSString stringWithFormat:@"http://github.com/CocoaPods/Specs/tree/master/%@", item.name];
 } else {
 return @"http://github.com/CocoaPods/Specs/commits";
 }
 
 
 - (NSString *)contents:(GItem *)item {
 return [self outputFor:@"%@ search --stats --no-color %@", self.cmd, item.name];
 }
 
 // TODO:
 - (NSString *)cat:(GItem *)item {
 return [self outputFor:@"%@ cat %@", self.cmd, item.name];
 }
 
 - (NSString *)deps:(GItem *)item {
 return [self outputFor:@"%@ search --stats --no-color %@", self.cmd, item.name];
 }
 
 - (NSString *)dependents:(GItem *)item {
 return [self outputFor:@"%@ search --stats --no-color %@", self.cmd, item.name];
 }
 
 
 - (NSString *)updateCmd {
 return [NSString stringWithFormat:@"%@ repo update  --no-color", self.cmd];
 }
 
 // TODO:
 + (NSString *)setupCmd {
 return @"sudo /opt/local/bin/gem1.9 install pod; /opt/local/bin/pod setup";
 }
 
 + (NSString *)removeCmd {
 return @"sudo /opt/local/bin/gem1.9 uninstall pod";
 }
 */
@end

package com.abstratt.mdd.target.jee

import com.abstratt.mdd.core.IRepository
import org.eclipse.uml2.uml.Signal

import static extension com.abstratt.kirra.mdd.schema.KirraMDDSchemaBuilder.*

class SignalGenerator extends AbstractJavaGenerator {
    
    new(IRepository repository) {
        super(repository)
    }
    
    def generateSignal(Signal signal) {
        '''
        package «signal.packagePrefix».event;
        
        import java.io.Serializable;
        
        public class «signal.name»Event implements Serializable {
            «signal.allAttributes.generateMany['''
                public «it.type.convertType.toJavaType» «it.name»;
            ''']» 
        }
        '''
    }
    
}